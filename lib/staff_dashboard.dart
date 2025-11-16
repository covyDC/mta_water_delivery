import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class StaffDashboardPage extends StatefulWidget {
  final Map<String, dynamic> staff;

  const StaffDashboardPage({super.key, required this.staff});

  @override
  State<StaffDashboardPage> createState() => _StaffDashboardPageState();
}

class _StaffDashboardPageState extends State<StaffDashboardPage> {
  int _selectedIndex = 0;

  late final Map<String, dynamic> staff;
  final db = FirebaseDatabase.instance.ref("deliveries");

  @override
  void initState() {
    super.initState();
    staff = widget.staff; // ← pass Firestore staff info
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Staff / Carrier Dashboard (${staff['name']})"),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: Text("Assigned"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.check_circle_outline),
                selectedIcon: Icon(Icons.check_circle),
                label: Text("Completed"),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text("Profile"),
              ),
            ],
          ),
          Expanded(child: _buildPage()),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return _assignedDeliveriesPage();
      case 1:
        return _completedDeliveriesPage();
      case 2:
        return _profilePage();
      default:
        return _assignedDeliveriesPage();
    }
  }

  Widget _assignedDeliveriesPage() {
    return StreamBuilder(
      stream: db
          .orderByChild("assignedTo")
          .equalTo(staff['id'])  // ← use Firestore staff ID
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          Map data = snapshot.data!.snapshot.value as Map;
          List deliveries = data.entries
              .where((e) => e.value["status"] == "assigned")
              .toList();

          if (deliveries.isEmpty) {
            return const Center(
              child: Text("No assigned deliveries.", style: TextStyle(fontSize: 18)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: deliveries.map((entry) {
              String id = entry.key;
              Map d = entry.value;

              return Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.local_shipping),
                  title: Text(d["customerName"]),
                  subtitle: Text("Address: ${d["address"]}"),
                  trailing: ElevatedButton(
                    onPressed: () {
                      db.child(id).update({"status": "completed"});
                    },
                    child: const Text("Mark Complete"),
                  ),
                ),
              );
            }).toList(),
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _completedDeliveriesPage() {
    return StreamBuilder(
      stream: db
          .orderByChild("assignedTo")
          .equalTo(staff['id'])  // ← use Firestore staff ID
          .onValue,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
          Map data = snapshot.data!.snapshot.value as Map;
          List deliveries = data.entries
              .where((e) => e.value["status"] == "completed")
              .toList();

          if (deliveries.isEmpty) {
            return const Center(
              child: Text("No completed deliveries yet.", style: TextStyle(fontSize: 18)),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: deliveries.map((entry) {
              Map d = entry.value;

              return Card(
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.check_circle),
                  title: Text(d["customerName"]),
                  subtitle: Text("Delivered to: ${d["address"]}"),
                ),
              );
            }).toList(),
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _profilePage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person, size: 80),
          const SizedBox(height: 15),
          Text(
            staff['name'] ?? "Unknown Staff",
            style: const TextStyle(fontSize: 22),
          ),
          Text(
            staff['email'] ?? "No email",
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            "Role: ${staff['role']}",
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}
