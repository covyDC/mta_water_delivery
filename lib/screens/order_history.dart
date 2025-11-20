import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Customer order history with filters and search
class OrderHistoryScreen extends StatefulWidget {
  final List<OrderHistory> orders;
  final Function(String) onOrderSelected;
  final Function(OrderFilter) onFilterChanged;

  const OrderHistoryScreen({
    super.key,
    required this.orders,
    required this.onOrderSelected,
    required this.onFilterChanged,
  });

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final _searchController = TextEditingController();
  String _selectedStatus = 'all';
  String _sortBy = 'recent';
  late List<OrderHistory> _filteredOrders;

  @override
  void initState() {
    super.initState();
    _filteredOrders = widget.orders;
  }

  @override
  void didUpdateWidget(OrderHistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orders != widget.orders) {
      _applyFilters();
    }
  }

  void _applyFilters() {
    var filtered = widget.orders.toList();

    // Search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered
          .where((order) =>
              order.orderId.toLowerCase().contains(query) ||
              order.productType.toLowerCase().contains(query) ||
              order.address.toLowerCase().contains(query))
          .toList();
    }

    // Status filter
    if (_selectedStatus != 'all') {
      filtered = filtered.where((order) => order.status == _selectedStatus).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'recent':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'oldest':
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'price_high':
        filtered.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case 'price_low':
        filtered.sort((a, b) => a.totalAmount.compareTo(b.totalAmount));
        break;
    }

    setState(() => _filteredOrders = filtered);

    widget.onFilterChanged(OrderFilter(
      status: _selectedStatus,
      searchQuery: _searchController.text,
      sortBy: _sortBy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => _applyFilters(),
              decoration: InputDecoration(
                hintText: 'Search orders...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Filters
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterChip(
                    label: 'All',
                    value: 'all',
                    selected: _selectedStatus == 'all',
                    onSelected: (value) {
                      setState(() => _selectedStatus = value);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    label: 'Pending',
                    value: 'pending',
                    selected: _selectedStatus == 'pending',
                    onSelected: (value) {
                      setState(() => _selectedStatus = value);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    label: 'Delivering',
                    value: 'in_progress',
                    selected: _selectedStatus == 'in_progress',
                    onSelected: (value) {
                      setState(() => _selectedStatus = value);
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    label: 'Completed',
                    value: 'completed',
                    selected: _selectedStatus == 'completed',
                    onSelected: (value) {
                      setState(() => _selectedStatus = value);
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Sort dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: DropdownButton<String>(
                value: _sortBy,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _sortBy = value);
                    _applyFilters();
                  }
                },
                items: const [
                  DropdownMenuItem(value: 'recent', child: Text('Most Recent')),
                  DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
                  DropdownMenuItem(value: 'price_high', child: Text('Price: High to Low')),
                  DropdownMenuItem(value: 'price_low', child: Text('Price: Low to High')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Orders list
          Expanded(
            child: _filteredOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No orders found',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = _filteredOrders[index];
                      return OrderHistoryCard(
                        order: order,
                        onTap: () => widget.onOrderSelected(order.orderId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required String value,
    required bool selected,
    required Function(String) onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: selected ? Colors.blue : Colors.grey.shade300,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.blue : Colors.grey,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

/// Order history card widget
class OrderHistoryCard extends StatelessWidget {
  final OrderHistory order;
  final VoidCallback onTap;

  const OrderHistoryCard({
    super.key,
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    final statusIcon = _getStatusIcon(order.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, y • h:mm a').format(order.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          order.status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Order details
              Row(
                children: [
                  Icon(Icons.shopping_bag, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.productType,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${order.quantity} units',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.address,
                      style: const TextStyle(fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Amount and delivery info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₱${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue,
                    ),
                  ),
                  if (order.estimatedDelivery != null)
                    Text(
                      'Est. ${DateFormat('MMM d').format(order.estimatedDelivery!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'in_progress':
        return Icons.local_shipping;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}

// Data models
class OrderHistory {
  final String orderId;
  final String productType;
  final int quantity;
  final double totalAmount;
  final String address;
  final String status; // pending, in_progress, completed, cancelled
  final DateTime createdAt;
  final DateTime? estimatedDelivery;
  final String? driverId;
  final String? notes;

  OrderHistory({
    required this.orderId,
    required this.productType,
    required this.quantity,
    required this.totalAmount,
    required this.address,
    required this.status,
    required this.createdAt,
    this.estimatedDelivery,
    this.driverId,
    this.notes,
  });

  factory OrderHistory.fromMap(Map<String, dynamic> map) {
    return OrderHistory(
      orderId: map['orderId'] ?? '',
      productType: map['productType'] ?? '',
      quantity: map['quantity'] ?? 0,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt']
          : DateTime.parse(map['createdAt'] ?? '2024-01-01'),
      estimatedDelivery: map['estimatedDelivery'] is DateTime
          ? map['estimatedDelivery']
          : null,
      driverId: map['driverId'],
      notes: map['notes'],
    );
  }
}

class OrderFilter {
  final String status;
  final String searchQuery;
  final String sortBy;

  OrderFilter({
    required this.status,
    required this.searchQuery,
    required this.sortBy,
  });
}
