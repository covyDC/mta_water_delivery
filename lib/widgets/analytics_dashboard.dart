import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Advanced analytics and reporting dashboard
class AnalyticsDashboard extends StatefulWidget {
  final List<OrderMetric> orderMetrics;
  final List<DeliveryMetric> deliveryMetrics;
  final List<RevenueMetric> revenueMetrics;
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTimeRange) onDateRangeChanged;

  const AnalyticsDashboard({
    super.key,
    required this.orderMetrics,
    required this.deliveryMetrics,
    required this.revenueMetrics,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
  });

  @override
  State<AnalyticsDashboard> createState() => _AnalyticsDashboardState();
}

class _AnalyticsDashboardState extends State<AnalyticsDashboard> {
  late DateTimeRange _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = DateTimeRange(
      start: widget.startDate,
      end: widget.endDate,
    );
  }

  Future<void> _selectDateRange() async {
    final newRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
    );

    if (newRange != null) {
      setState(() => _selectedRange = newRange);
      widget.onDateRangeChanged(newRange);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date range selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Analytics Dashboard',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              OutlinedButton.icon(
                onPressed: _selectDateRange,
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  '${DateFormat('MMM d').format(_selectedRange.start)} - ${DateFormat('MMM d, y').format(_selectedRange.end)}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Key metrics row
          if (isMobile)
            Column(
              children: _buildMetricCards(),
            )
          else
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _buildMetricCards(),
            ),
          const SizedBox(height: 24),

          // Charts section
          Text(
            'Performance Trends',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          OrderTrendChart(metrics: widget.orderMetrics),
          const SizedBox(height: 24),
          RevenueTrendChart(metrics: widget.revenueMetrics),
          const SizedBox(height: 24),
          DeliveryStatusChart(metrics: widget.deliveryMetrics),
        ],
      ),
    );
  }

  List<Widget> _buildMetricCards() {
    final metrics = [
      ('Total Orders', widget.orderMetrics.length.toString(), Icons.shopping_cart, Colors.blue),
      ('Completed', _countCompleted(), Icons.check_circle, Colors.green),
      ('In Progress', _countInProgress(), Icons.local_shipping, Colors.orange),
      ('Total Revenue', _totalRevenue(), Icons.trending_up, Colors.purple),
    ];

    return metrics
        .map(
          (metric) => MetricCard(
            title: metric.$1,
            value: metric.$2,
            icon: metric.$3,
            color: metric.$4,
          ),
        )
        .toList();
  }

  String _countCompleted() {
    return widget.deliveryMetrics.where((m) => m.status == 'completed').length.toString();
  }

  String _countInProgress() {
    return widget.deliveryMetrics.where((m) => m.status == 'in_progress').length.toString();
  }

  String _totalRevenue() {
    final total = widget.revenueMetrics.fold<double>(
      0,
      (sum, metric) => sum + metric.amount,
    );
    return '₱${total.toStringAsFixed(2)}';
  }
}

/// Metric card widget
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Text(
                '▲',
                style: TextStyle(color: Colors.green, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Order trend chart
class OrderTrendChart extends StatelessWidget {
  final List<OrderMetric> metrics;

  const OrderTrendChart({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Orders by Date',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (metrics.isEmpty)
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: metrics.length,
                  itemBuilder: (context, index) {
                    final metric = metrics[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 30,
                            height: (metric.count / 10 * 150).toDouble().clamp(10, 150),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('MMM d').format(metric.date),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Revenue trend chart
class RevenueTrendChart extends StatelessWidget {
  final List<RevenueMetric> metrics;

  const RevenueTrendChart({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Revenue Trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (metrics.isEmpty)
              SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    'No data available',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: metrics.length,
                  itemBuilder: (context, index) {
                    final metric = metrics[index];
                    final maxAmount = metrics.map((m) => m.amount).reduce((a, b) => a > b ? a : b);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 30,
                            height: (metric.amount / maxAmount * 150).clamp(10, 150),
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '₱${(metric.amount / 1000).toStringAsFixed(1)}k',
                            style: const TextStyle(fontSize: 9),
                          ),
                          Text(
                            DateFormat('MMM d').format(metric.date),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Delivery status chart
class DeliveryStatusChart extends StatelessWidget {
  final List<DeliveryMetric> metrics;

  const DeliveryStatusChart({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final completed = metrics.where((m) => m.status == 'completed').length;
    final inProgress = metrics.where((m) => m.status == 'in_progress').length;
    final failed = metrics.where((m) => m.status == 'failed').length;
    final total = metrics.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Status Distribution',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (total == 0)
              SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    'No deliveries',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ),
              )
            else
              Column(
                children: [
                  _buildStatusBar('Completed', completed, total, Colors.green),
                  _buildStatusBar('In Progress', inProgress, total, Colors.orange),
                  _buildStatusBar('Failed', failed, total, Colors.red),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text('$count (${percentage.toStringAsFixed(1)}%)'),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

// Data models
class OrderMetric {
  final DateTime date;
  final int count;

  OrderMetric({required this.date, required this.count});

  factory OrderMetric.fromMap(Map<String, dynamic> map) {
    return OrderMetric(
      date: map['date'] is DateTime ? map['date'] : DateTime.parse(map['date']),
      count: map['count'] ?? 0,
    );
  }
}

class DeliveryMetric {
  final String status; // completed, in_progress, failed
  final int count;
  final DateTime date;

  DeliveryMetric({
    required this.status,
    required this.count,
    required this.date,
  });

  factory DeliveryMetric.fromMap(Map<String, dynamic> map) {
    return DeliveryMetric(
      status: map['status'] ?? '',
      count: map['count'] ?? 0,
      date: map['date'] is DateTime ? map['date'] : DateTime.parse(map['date']),
    );
  }
}

class RevenueMetric {
  final DateTime date;
  final double amount;

  RevenueMetric({required this.date, required this.amount});

  factory RevenueMetric.fromMap(Map<String, dynamic> map) {
    return RevenueMetric(
      date: map['date'] is DateTime ? map['date'] : DateTime.parse(map['date']),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
