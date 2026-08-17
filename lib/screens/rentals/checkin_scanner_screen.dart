import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:async';
import 'dart:math';
import 'package:go_router/go_router.dart';
import '../../core/mcp_client.dart';
import '../../models/rental_item.dart';
import '../../providers/rental_provider.dart';
import '../../providers/equipment_provider.dart';
import '../../providers/dashboard_provider.dart';

class CheckinScannerScreen extends ConsumerStatefulWidget {
  const CheckinScannerScreen({
    super.key,
    required this.rentalId,
    required this.items,
  });

  final String rentalId;
  final List<RentalItem> items;

  @override
  ConsumerState<CheckinScannerScreen> createState() =>
      _CheckinScannerScreenState();
}

class _CheckinScannerScreenState extends ConsumerState<CheckinScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  // Set of rental item IDs that have been verified.
  final Set<String> _verifiedIds = {};
  final Set<String> _returnedAssetIds = {};
  final Map<String, int> _returnedQuantities = {};
  final String _requestId = _newReturnRequestId();

  // Track recently processed barcodes so we don't spam the API
  final Set<String> _recentScans = {};

  bool _isProcessing = false;
  bool _isCheckingIn = false;

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
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
        break;
      case AppLifecycleState.resumed:
        // Restart the scanner when app resumes
        unawaited(_controller.start());
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? rawValue = barcodes.first.rawValue;
      if (rawValue != null && !_recentScans.contains(rawValue)) {
        setState(() {
          _isProcessing = true;
          _recentScans.add(rawValue);
        });

        try {
          final data =
              await mcpClient.get('/barcodes/${Uri.encodeComponent(rawValue)}');
          final lookup = data['lookup'] as Map<String, dynamic>?;

          if (lookup != null && lookup['result_type'] != 'unknown') {
            final assetId = lookup['asset_id'] as String?;
            if (assetId == null && lookup['tracking_mode'] == 'serialized') {
              throw McpApiException(
                'AMBIGUOUS_PRODUCT_BARCODE',
                'Scan this equipment\'s individual barcode.',
              );
            }
            if (assetId == null) {
              throw McpApiException(
                'UNKNOWN_BARCODE',
                'Scan an individual physical asset barcode.',
              );
            }
            if (_returnedAssetIds.contains(assetId)) {
              _showNotInRentalOrVerified();
              return;
            }
            final rentalItemId =
                await ref.read(rentalRepositoryProvider).scanReturnAsset(
                      rentalId: widget.rentalId,
                      barcode: rawValue,
                      disposition: 'returned',
                    );
            if (!widget.items.any((item) => item.id == rentalItemId)) {
              _showNotInRentalOrVerified();
              return;
            }
            setState(() {
              _returnedAssetIds.add(assetId);
              _verifiedIds.add(rentalItemId);
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Item returned'),
                backgroundColor: Color(0xFF4CAF50),
                duration: Duration(seconds: 2),
              ));
            }
          } else {
            throw McpApiException(
              'UNKNOWN_BARCODE',
              'Barcode not found.',
            );
          }
        } catch (e) {
          if (mounted) {
            if (e
                .toString()
                .toLowerCase()
                .contains('does not belong to this active rental')) {
              _showNotInRentalOrVerified();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Barcode lookup failed: $e'),
                backgroundColor: const Color(0xFFFF5252),
                duration: const Duration(seconds: 2),
              ));
            }
          }
        } finally {
          // Clear recent scans after a few seconds to allow rescanning if needed
          Future.delayed(const Duration(seconds: 3), () {
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

  Future<void> _handleCheckin() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete return?'),
        content: const Text('This will finalize the returned items.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Complete return'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isCheckingIn = true);
    try {
      await ref.read(rentalRepositoryProvider).completeReturn(
            rentalId: widget.rentalId,
            quantityLines: _quantityReturnPayload(),
            requestId: _requestId,
          );
      ref.invalidate(rentalDetailProvider(widget.rentalId));
      ref.invalidate(rentalItemsProvider(widget.rentalId));
      ref.invalidate(equipmentListProvider);
      ref.invalidate(dashboardStatsProvider);
      if (mounted) {
        context.pop(); // Go back to rental detail
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFFF5252),
        ));
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quantityItems =
        widget.items.where((item) => item.lineType == 'quantity');
    final serializedCount = widget.items
        .where((item) => item.lineType == 'serialized')
        .fold<int>(0, (count, item) => count + item.qty.toInt());
    final allVerified = _returnedAssetIds.length >= serializedCount &&
        quantityItems.every((item) => _returnedQuantities.containsKey(item.id));

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: const Text(
          'Return Scanner',
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
                        color: allVerified
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE8A838),
                        width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  child: Text(
                    allVerified
                        ? 'Set quantities and complete return'
                        : 'Scan items to verify',
                    style: TextStyle(
                      color: allVerified
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFEEEEF5),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: const [
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
                          'Items (${_returnedAssetIds.length + _returnedQuantities.length} / ${serializedCount + quantityItems.length})',
                          style: const TextStyle(
                            color: Color(0xFFEEEEF5),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: widget.items.length,
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        final isVerified = _verifiedIds.contains(item.id) ||
                            _returnedQuantities.containsKey(item.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252533),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isVerified
                                  ? const Color(0xFF4CAF50)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isVerified
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_unchecked_rounded,
                                color: isVerified
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFF9999AA),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.equipmentName ?? 'Equipment',
                                      style: const TextStyle(
                                        color: Color(0xFFEEEEF5),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      item.lineType == 'serialized'
                                          ? 'QR / barcode: ${item.serialNo ?? 'Unknown'}'
                                          : 'Quantity: ${item.qty.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        color: Color(0xFF9999AA),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (item.assetId != null && !isVerified)
                                TextButton(
                                  onPressed: () => setState(
                                    () => _verifiedIds.add(item.id),
                                  ),
                                  child: const Text('Mark returned'),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  if (quantityItems.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: quantityItems
                            .map((item) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: OutlinedButton.icon(
                                    onPressed: () => _setReturnedQuantity(item),
                                    icon: const Icon(Icons.numbers_rounded),
                                    label: Text(
                                        'Set returned quantity: ${item.equipmentId}'),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),

                  // Return Button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: _isCheckingIn
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF0F0F13)),
                              )
                            : const Text('Complete Return'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8A838),
                          foregroundColor: const Color(0xFF0F0F13),
                          disabledBackgroundColor:
                              const Color(0xFFE8A838).withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: (allVerified && !_isCheckingIn)
                            ? _handleCheckin
                            : null,
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

  Future<void> _setReturnedQuantity(RentalItem item) async {
    final controller = TextEditingController(
      text: (_returnedQuantities[item.id] ?? item.qty.toInt()).toString(),
    );
    final returned = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Returned quantity'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(labelText: 'Out of ${item.qty.toInt()}'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (returned == null) return;
    if (returned < 0 || returned > item.qty.toInt()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid returned quantity.')));
      }
      return;
    }
    if (mounted) {
      setState(() => _returnedQuantities[item.id] = returned);
      final missing = item.qty.toInt() - returned;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(missing == 0
            ? 'Returned ${item.qty.toInt()} item(s)'
            : 'Returned $returned — $missing item(s) missing'),
        backgroundColor:
            missing == 0 ? const Color(0xFF4CAF50) : const Color(0xFFE8A838),
      ));
    }
  }

  List<Map<String, dynamic>> _quantityReturnPayload() => widget.items
      .where((item) => item.lineType == 'quantity')
      .map((item) => {
            'rental_item_id': item.id,
            'returned_quantity': _returnedQuantities[item.id] ?? 0,
          })
      .toList();

  void _showNotInRentalOrVerified() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Item not in rental or already verified'),
      backgroundColor: Color(0xFFFF5252),
      duration: Duration(seconds: 2),
    ));
  }
}

String _newReturnRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
