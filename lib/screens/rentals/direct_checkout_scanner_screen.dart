import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/mcp_client.dart';
import '../../models/rental_line_input.dart';

/// The scanned loading cart for a walk-up rental. No rental exists yet: this
/// screen only derives product quantities and remembers physical asset labels.
class DirectCheckoutDraft {
  const DirectCheckoutDraft({
    required this.lines,
    required this.serializedBarcodes,
  });

  final List<RentalLineInput> lines;
  final List<String> serializedBarcodes;
}

class DirectCheckoutScannerScreen extends StatefulWidget {
  const DirectCheckoutScannerScreen({super.key});

  @override
  State<DirectCheckoutScannerScreen> createState() =>
      _DirectCheckoutScannerScreenState();
}

class _DirectCheckoutScannerScreenState
    extends State<DirectCheckoutScannerScreen> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.normal,
  );
  final Map<String, _ScannedProduct> _products = {};
  final Set<String> _serializedBarcodes = {};
  final Set<String> _inFlight = {};
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.start());
    } else {
      unawaited(_controller.stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || capture.barcodes.isEmpty) return;
    final barcode = capture.barcodes.first.rawValue?.trim();
    if (barcode == null || barcode.isEmpty || _inFlight.contains(barcode)) {
      return;
    }
    setState(() {
      _processing = true;
      _inFlight.add(barcode);
    });
    try {
      final response =
          await mcpClient.get('/barcodes/${Uri.encodeComponent(barcode)}');
      final lookup = response['lookup'] as Map<String, dynamic>?;
      if (lookup == null || lookup['result_type'] == 'unknown') {
        final created = await _registerUnknownBarcode(barcode);
        if (created == null) return;
        _serializedBarcodes.add(barcode);
        _addToCart(created);
        _message('${created.name} added to inventory and checkout',
            const Color(0xFF4CAF50));
        return;
      }

      final productId = lookup['product_id'] as String?;
      final productName = lookup['product_name'] as String?;
      final trackingMode = lookup['tracking_mode'] as String?;
      if (productId == null || productName == null || trackingMode == null) {
        throw McpApiException(
            'INVALID_BARCODE', 'Barcode has incomplete inventory data.');
      }

      if (lookup['result_type'] == 'asset') {
        if (trackingMode != 'serialized') {
          throw McpApiException(
              'INVALID_BARCODE', 'This is not a serialized rental asset.');
        }
        if ((lookup['children'] as List<dynamic>? ?? []).isNotEmpty) {
          throw McpApiException('CONTAINER_BARCODE',
              'Scan each physical asset in this container.');
        }
        if (!_serializedBarcodes.add(barcode)) {
          throw McpApiException(
              'DUPLICATE_BARCODE', 'This asset is already in the scan cart.');
        }
      } else {
        if (trackingMode != 'quantity') {
          throw McpApiException('ASSET_BARCODE_REQUIRED',
              'Scan an individual asset barcode for this model.');
        }
      }

      _addToCart(_ScannedProduct(
        productId: productId,
        name: productName,
        trackingMode: trackingMode,
      ));
      _message('$productName added', const Color(0xFF4CAF50));
    } on McpApiException catch (error) {
      _message(error.message, const Color(0xFFFF5252));
    } catch (_) {
      _message(
          'Could not read this barcode. Try again.', const Color(0xFFFF5252));
    } finally {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _inFlight.remove(barcode));
      });
      if (mounted) setState(() => _processing = false);
    }
  }

  void _addToCart(_ScannedProduct item) {
    setState(() {
      final entry = _products.putIfAbsent(
        item.productId,
        () => item,
      );
      entry.quantity++;
    });
  }

  Future<_ScannedProduct?> _registerUnknownBarcode(String barcode) async {
    final nameController = TextEditingController();
    try {
      final shouldCreate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Add scanned equipment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                barcode,
                style: const TextStyle(color: Color(0xFF9999AA)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Equipment/model name *',
                  helperText:
                      'A serialized asset will use this scanned barcode.',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Add & continue'),
            ),
          ],
        ),
      );
      if (shouldCreate != true) return null;

      final response = await mcpClient.post('/products', body: {
        'name': nameController.text.trim(),
        'tracking_mode': 'serialized',
        'daily_rate': 0,
        'initial_quantity': 0,
        'asset_barcode': barcode,
      });
      final product = response['product'] as Map<String, dynamic>?;
      final productId = product?['id'] as String?;
      final productName = product?['name'] as String?;
      if (productId == null || productName == null) {
        throw McpApiException(
            'CREATE_FAILED', 'New equipment was not returned by inventory.');
      }
      return _ScannedProduct(
        productId: productId,
        name: productName,
        trackingMode: 'serialized',
      );
    } finally {
      nameController.dispose();
    }
  }

  void _finish() {
    if (_products.isEmpty) {
      _message('Scan at least one item.', const Color(0xFFFF5252));
      return;
    }
    final lines = _products.values
        .map(
          (item) => RentalLineInput(
            lineType: item.trackingMode,
            itemCode: item.productId,
            itemName: item.name,
            qty: item.quantity.toDouble(),
            dailyRate: 0,
          ),
        )
        .toList();
    context.pop(DirectCheckoutDraft(
      lines: lines,
      serializedBarcodes: _serializedBarcodes.toList(growable: false),
    ));
  }

  void _message(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF0F0F13),
        appBar: AppBar(
          title: const Text('Scan loaded equipment'),
          actions: [
            TextButton(
              onPressed: _finish,
              child: const Text('Continue'),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  MobileScanner(controller: _controller, onDetect: _onDetect),
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFFE8A838), width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A24),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: _products.isEmpty
                    ? const Center(
                        child: Text(
                          'Scan each loaded asset. Scan a quantity-product label once per unit.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF9999AA)),
                        ),
                      )
                    : ListView(
                        children: _products.values
                            .map(
                              (item) => ListTile(
                                leading: const Icon(Icons.check_circle,
                                    color: Color(0xFF4CAF50)),
                                title: Text(item.name),
                                trailing: Text('× ${item.quantity}'),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
          ],
        ),
      );
}

class _ScannedProduct {
  _ScannedProduct({
    required this.productId,
    required this.name,
    required this.trackingMode,
  });

  final String productId;
  final String name;
  final String trackingMode;
  int quantity = 0;
}
