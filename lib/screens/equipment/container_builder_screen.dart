import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/mcp_client.dart';

class ContainerBuilderScreen extends ConsumerStatefulWidget {
  const ContainerBuilderScreen({super.key});

  @override
  ConsumerState<ContainerBuilderScreen> createState() =>
      _ContainerBuilderScreenState();
}

class _ContainerBuilderScreenState extends ConsumerState<ContainerBuilderScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  String? _parentBarcode;
  final Set<String> _childBarcodes = {};
  final Set<String> _recentScans = {};

  bool _isProcessing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
      case AppLifecycleState.resumed:
        _controller.start();
      case AppLifecycleState.inactive:
        _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _isSaving) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? rawValue = barcodes.first.rawValue;
      if (rawValue != null && !_recentScans.contains(rawValue)) {
        setState(() {
          _isProcessing = true;
          _recentScans.add(rawValue);
        });

        try {
          if (_parentBarcode == null) {
            setState(() {
              _parentBarcode = rawValue;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Parent set: $_parentBarcode'),
                backgroundColor: const Color(0xFF4CAF50),
                duration: const Duration(seconds: 2),
              ));
            }
          } else if (rawValue != _parentBarcode &&
              !_childBarcodes.contains(rawValue)) {
            setState(() {
              _childBarcodes.add(rawValue);
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Added child: $rawValue'),
                backgroundColor: const Color(0xFF4CAF50),
                duration: const Duration(seconds: 1),
              ));
            }
          }
        } finally {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _recentScans.remove(rawValue);
              });
            }
          });
          if (mounted) setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<void> _handleSave() async {
    if (_parentBarcode == null || _childBarcodes.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await mcpClient.post(
        '/assets/link',
        body: {
          'parent_barcode': _parentBarcode,
          'child_barcodes': _childBarcodes.toList(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Container linked successfully!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
        context.pop(); // Go back
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: const Color(0xFFFF5252),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: const Text(
          'Build Container',
          style: TextStyle(
            color: Color(0xFFEEEEF5),
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFEEEEF5)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Scanner area (top half)
          Expanded(
            flex: 4,
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Camera Error:\n${error.errorDetails?.message ?? error.errorCode.name}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _parentBarcode == null
                          ? const Color(0xFFE8A838)
                          : const Color(0xFF4CAF50),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  child: Text(
                    _parentBarcode == null
                        ? 'Scan Parent Barcode (e.g. Flight Case)'
                        : 'Scan Child Barcodes',
                    style: const TextStyle(
                      color: Color(0xFFEEEEF5),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 1),
                          blurRadius: 4.0,
                          color: Colors.black87,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List of items (bottom half)
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A24),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _parentBarcode == null
                              ? 'Awaiting Parent...'
                              : 'Parent: $_parentBarcode',
                          style: const TextStyle(
                            color: Color(0xFFE8A838),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_parentBarcode != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _parentBarcode = null;
                                _childBarcodes.clear();
                              });
                            },
                            child: const Text('Reset'),
                          ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Child Items',
                        style: TextStyle(
                          color: Color(0xFFEEEEF5),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _childBarcodes.length,
                      itemBuilder: (context, index) {
                        final child = _childBarcodes.elementAt(index);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252533),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4CAF50),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF4CAF50),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  child,
                                  style: const TextStyle(
                                    color: Color(0xFFEEEEF5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Color(0xFF9999AA)),
                                onPressed: () {
                                  setState(() {
                                    _childBarcodes.remove(child);
                                  });
                                },
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Save Button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.link_rounded),
                        label: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF0F0F13)),
                              )
                            : Text('Link ${_childBarcodes.length} Items'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8A838),
                          foregroundColor: const Color(0xFF0F0F13),
                          disabledBackgroundColor:
                              const Color(0xFFE8A838).withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed:
                            (_parentBarcode == null || _childBarcodes.isEmpty || _isSaving)
                                ? null
                                : _handleSave,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
