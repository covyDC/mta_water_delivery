// RadioListTile's groupValue/onChanged were deprecated in newer Flutter
// versions; the RadioGroup API is recommended. Keep using RadioListTile for
// now for compatibility, and ignore the deprecation to keep the analyzer
// clean until we migrate to RadioGroup across the app.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// A small dialog widget that displays a list of drivers (id + metadata) and
/// allows selecting one. Returns the selected driver's id when 'Assign' is
/// tapped, otherwise returns null when cancelled.
class DriverSelectionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> drivers; // each map must include 'id', optionally 'name','phone','status'

  const DriverSelectionDialog({super.key, required this.drivers});

  @override
  State<DriverSelectionDialog> createState() => _DriverSelectionDialogState();
}

class _DriverSelectionDialogState extends State<DriverSelectionDialog> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    if (widget.drivers.isEmpty) {
      return AlertDialog(
        title: const Text('Assign to Driver'),
        content: const Text('No drivers are currently online'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Close')),
        ],
      );
    }

    return AlertDialog(
      title: const Text('Assign to Driver'),
      content: SizedBox(
        width: double.maxFinite,
        height: 240,
        child: ListView.builder(
          itemCount: widget.drivers.length,
          itemBuilder: (ctx, idx) {
            final d = widget.drivers[idx];
            // Try many common name fields so we show a human-friendly label
            final rawName = (
                d['fullName'] ??
                d['name'] ??
                d['displayName'] ??
                // sometimes first/last are stored separately
                ((d['firstName'] ?? d['first_name']) != null && (d['lastName'] ?? d['last_name']) != null
                  ? '${(d['firstName'] ?? d['first_name']).toString().trim()} ${(d['lastName'] ?? d['last_name']).toString().trim()}'
                  : null) ??
                '')
              ?.toString() ?? '';
            bool looksLikeEmail(String s) => s.contains('@') && s.contains('.');
            // Prefer a readable full name — avoid showing raw emails. When no
            // friendly name exists show a short id instead of the full uid so
            // the UI is easier to scan.
            final name = (rawName.isNotEmpty && !looksLikeEmail(rawName))
              ? rawName
              : 'Driver ${(d['id']?.toString() ?? '').substring(0, 6)}';
            final phone = d['phone'] ?? d['contact'] ?? '';
            final status = d['status'] ?? '';
            final emailFallback = (d['email'] ?? d['contactEmail'] ?? '')?.toString() ?? '';

            return RadioListTile<String>(
              title: Text(name),
              subtitle: Text([if (phone.isNotEmpty) phone, if (emailFallback.isNotEmpty) emailFallback, if (status.isNotEmpty) status].join(' • ')),
              value: d['id'] as String,
              groupValue: _selectedId,
              onChanged: (v) => setState(() => _selectedId = v),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.of(context).pop(_selectedId), child: const Text('Assign')),
      ],
    );
  }
}
