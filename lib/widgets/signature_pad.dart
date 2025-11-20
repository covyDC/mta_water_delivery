import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Signature capture widget for driver proof-of-delivery
class SignaturePad extends StatefulWidget {
  final double width;
  final double height;
  final Color strokeColor;
  final double strokeWidth;
  final Function(Uint8List signature) onSignatureSaved;
  final VoidCallback? onSignatureCleared;

  const SignaturePad({
    super.key,
    this.width = 300,
    this.height = 200,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.0,
    required this.onSignatureSaved,
    this.onSignatureCleared,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<Offset?> _points = [];
  late PainterController _painterController;

  @override
  void initState() {
    super.initState();
    _painterController = PainterController();
  }

  void _clearSignature() {
    setState(() {
      _points.clear();
    });
    widget.onSignatureCleared?.call();
  }

  Future<void> _saveSignature() async {
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign before saving')),
      );
      return;
    }

    try {
      final image = await _painterController.renderImage();
      final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes != null) {
        widget.onSignatureSaved(pngBytes.buffer.asUint8List());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving signature: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Customer Signature',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: GestureDetector(
            onPanDown: (DragDownDetails details) {
              setState(() {
                _points.add(details.localPosition);
              });
            },
            onPanUpdate: (DragUpdateDetails details) {
              setState(() {
                _points.add(details.localPosition);
              });
            },
            onPanEnd: (DragEndDetails details) {
              setState(() {
                _points.add(null);
              });
            },
            child: CustomPaint(
              painter: SignaturePainter(
                points: _points,
                strokeColor: widget.strokeColor,
                strokeWidth: widget.strokeWidth,
              ),
              size: Size(widget.width, widget.height),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _clearSignature,
              icon: const Icon(Icons.clear),
              label: const Text('Clear'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _saveSignature,
              icon: const Icon(Icons.save),
              label: const Text('Save Signature'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _painterController.dispose();
    super.dispose();
  }
}

/// Custom painter for signature drawing
class SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color strokeColor;
  final double strokeWidth;

  SignaturePainter({
    required this.points,
    required this.strokeColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

/// Painter controller for signature management
class PainterController {
  final ui.PictureRecorder _recorder = ui.PictureRecorder();

  Future<ui.Image> renderImage() async {
    // This is a placeholder - in production, you'd use flutter_signature_pad package
    throw UnimplementedError('Use flutter_signature_pad package for full implementation');
  }

  void dispose() {
    // Cleanup
  }
}

/// Dialog for capturing delivery signature
class SignatureDialog extends StatefulWidget {
  final String customerName;
  final Function(Uint8List signature) onSignatureCaptured;

  const SignatureDialog({
    super.key,
    required this.customerName,
    required this.onSignatureCaptured,
  });

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  late Uint8List? _signature;

  @override
  void initState() {
    super.initState();
    _signature = null;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Get Signature',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Please ask ${widget.customerName} to sign below:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              SignaturePad(
                width: double.infinity,
                height: 250,
                onSignatureSaved: (signature) {
                  setState(() => _signature = signature);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Signature captured!')),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _signature != null
                        ? () {
                            widget.onSignatureCaptured(_signature!);
                            Navigator.of(context).pop();
                          }
                        : null,
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
