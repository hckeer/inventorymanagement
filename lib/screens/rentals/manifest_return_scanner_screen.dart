import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/rental_provider.dart';
import '../../core/mcp_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ManifestReturnScannerScreen extends ConsumerStatefulWidget {
  const ManifestReturnScannerScreen(
      {super.key, required this.rentalId, required this.barcodes});
  final String rentalId;
  final List<String> barcodes;
  @override
  ConsumerState<ManifestReturnScannerScreen> createState() =>
      _ManifestReturnScannerScreenState();
}

class _ManifestReturnScannerScreenState
    extends ConsumerState<ManifestReturnScannerScreen> {
  final _controller = MobileScannerController();
  final _returned = <String>{};
  final _recent = <String>{};
  final _requestId = _uuid();
  bool _saving = false;
  void _scan(String barcode) {
    final value = barcode.trim();
    if (!widget.barcodes.contains(value)) {
      _message('This barcode is not in this rental.');
      return;
    }
    if (!_returned.add(value)) {
      _message('Already scanned.');
      return;
    }
    setState(() {});
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final missing = await ref
          .read(rentalListProvider.notifier)
          .returnManifest(
              rentalId: widget.rentalId,
              barcodes: _returned.toList(),
              requestId: _requestId);
      if (!mounted) return;
      _message(missing.isEmpty
          ? 'All items returned.'
          : 'Missing: ${missing.join(', ')}');
      context.pop();
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final missing =
        widget.barcodes.where((b) => !_returned.contains(b)).toList();
    return Scaffold(
        appBar: AppBar(title: const Text('Return Scanner')),
        body: Column(children: [
          Expanded(
              child: MobileScanner(
                  controller: _controller,
                  onDetect: (c) {
                    final v = c.barcodes.firstOrNull?.rawValue;
                    if (v != null && !_recent.contains(v)) {
                      _recent.add(v);
                      _scan(v);
                      Future.delayed(
                          const Duration(seconds: 2), () => _recent.remove(v));
                    }
                  })),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  '${_returned.length} / ${widget.barcodes.length} scanned')),
          Expanded(
              child: ListView(
                  children: missing
                      .map((b) => ListTile(
                          leading: const Icon(Icons.radio_button_unchecked),
                          title: Text(b)))
                      .toList())),
          Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                  onPressed: _saving ? null : _finish,
                  child: Text(_saving
                      ? 'Saving...'
                      : missing.isEmpty
                          ? 'Complete return'
                          : 'Complete return with ${missing.length} missing')))
        ]));
  }
}

String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
