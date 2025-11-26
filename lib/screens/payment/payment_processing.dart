import 'package:flutter/material.dart';
class PaymentProcessingPage extends StatefulWidget {
  final double amount;
  final String paymentMethod;

  const PaymentProcessingPage({super.key, required this.amount, required this.paymentMethod});

  @override
  State<PaymentProcessingPage> createState() => _PaymentProcessingPageState();
}

class _PaymentProcessingPageState extends State<PaymentProcessingPage> {
  bool _processing = false;

  Future<void> _simulatePayment() async {
    setState(() => _processing = true);
    // Simulate a network/payment delay
    await Future.delayed(const Duration(seconds: 2));
    // Simulated payment completed (UI-only)
    if (!mounted) return;
    setState(() => _processing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful')));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ₱${widget.amount.toStringAsFixed(2)}'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _processing ? null : _simulatePayment,
              icon: const Icon(Icons.payment),
              label: Text(_processing ? 'Processing...' : 'Simulate ${widget.paymentMethod} Payment'),
            ),
            const SizedBox(height: 12),
            const Text('This is a simulated payment flow. Integrate real providers later.'),
          ],
        ),
      ),
    );
  }
}
