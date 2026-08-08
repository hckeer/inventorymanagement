import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import '../../core/mcp_client.dart';
import '../../models/rental_item.dart';
import '../../providers/rental_provider.dart';

class CheckoutScannerScreen extends ConsumerStatefulWidget {
  const CheckoutScannerScreen({
    super.key,
    required this.rentalId,
    required this.items,
  });

  final String rentalId;
  final List<RentalItem> items;

  @override
  ConsumerState<CheckoutScannerScreen> createState() =>
      _CheckoutScannerScreenState();
}

class _CheckoutScannerScreenState extends ConsumerState<CheckoutScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  // Set of rental item IDs that have been verified.
  final Set<String> _verifiedIds = {};
  
  // Track recently processed barcodes so we don't spam the API
  final Set<String> _recentScans = {};
  
  bool _isProcessing = false;
  bool _isCheckingOut = false;

  @override
  void dispose() {
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
          final data = await mcpClient.get('/barcodes/${Uri.encodeComponent(rawValue)}');
          final lookup = data['lookup'] as Map<String, dynamic>?;
          
          if (lookup != null && lookup['result_type'] != 'unknown') {
            final assetId = lookup['asset_id'] as String?;
            final productId = lookup['product_id'] as String?;
            
            // Find a matching item in the rental
            RentalItem? match;
            
            if (assetId != null) {
              match = widget.items.where((item) => item.assetId == assetId).firstOrNull;
            } else if (productId != null) {
              // For quantity items, match on product ID that isn't fully verified yet
              match = widget.items.where((item) => 
                item.productId == productId && 
                !_verifiedIds.contains(item.id)
              ).firstOrNull;
            }

            if (match != null && !_verifiedIds.contains(match.id)) {
              setState(() {
                _verifiedIds.add(match!.id);
              });
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Verified: ${match.equipmentId}'),
                  backgroundColor: const Color(0xFF4CAF50),
                  duration: const Duration(seconds: 2),
                ));
              }
            } else if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text('Item not in rental or already verified'),
                backgroundColor: const Color(0xFFFF5252),
                duration: const Duration(seconds: 2),
              ));
            }
          }
        } catch (e) {
          // Ignore network errors or bad lookups during continuous scan
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

  Future<void> _handleCheckout() async {
    setState(() => _isCheckingOut = true);
    try {
      await ref.read(rentalListProvider.notifier).checkout(widget.rentalId);
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
      if (mounted) setState(() => _isCheckingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allVerified = _verifiedIds.length == widget.items.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F13),
        title: const Text(
          'Scan to Checkout',
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
                ),
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: allVerified ? const Color(0xFF4CAF50) : const Color(0xFFE8A838), 
                      width: 3
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  child: Text(
                    allVerified ? 'All items verified!' : 'Scan items to verify',
                    style: TextStyle(
                      color: allVerified ? const Color(0xFF4CAF50) : const Color(0xFFEEEEF5),
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
                          'Items (${_verifiedIds.length} / ${widget.items.length})',
                          style: const TextStyle(
                            color: Color(0xFFEEEEF5),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Manual override button for debugging or broken barcodes
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (final item in widget.items) {
                                _verifiedIds.add(item.id);
                              }
                            });
                          },
                          child: const Text('Verify All Manually'),
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
                        final isVerified = _verifiedIds.contains(item.id);
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF252533),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isVerified ? const Color(0xFF4CAF50) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isVerified ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                color: isVerified ? const Color(0xFF4CAF50) : const Color(0xFF9999AA),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.lineType == 'serialized'
                                      ? (item.serialNo ?? item.equipmentId)
                                      : '${item.equipmentId} × ${item.qty.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Color(0xFFEEEEF5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  
                  // Checkout Button
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.outbox_rounded),
                        label: _isCheckingOut
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F0F13)),
                              )
                            : const Text('Confirm Checkout'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8A838),
                          foregroundColor: const Color(0xFF0F0F13),
                          disabledBackgroundColor: const Color(0xFFE8A838).withOpacity(0.3),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: (!allVerified || _isCheckingOut) ? null : _handleCheckout,
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
