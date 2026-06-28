import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error_handler.dart';
import '../../models/warehouse.dart';
import '../../repositories/warehouse_repository.dart';

final warehouseRepositoryProvider = Provider(
  (ref) => WarehouseRepository(),
);

enum WarehouseScanMode { audit, dispatch, stockReturn }

enum WarehouseSessionStep {
  pickMode,
  scanSource,
  scanDestination,
  scanItems,
  review,
  done,
}

enum WarehouseMessageTone { system, ok, warn, error, muted }

class WarehouseMessage {
  const WarehouseMessage({
    required this.tone,
    required this.text,
    this.detail,
  });

  final WarehouseMessageTone tone;
  final String text;
  final String? detail;
}

class WarehouseScreen extends ConsumerStatefulWidget {
  const WarehouseScreen({super.key});

  @override
  ConsumerState<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends ConsumerState<WarehouseScreen> {
  final _scanController = TextEditingController();
  final _scrollController = ScrollController();
  final _scanFocus = FocusNode();

  WarehouseScanMode _mode = WarehouseScanMode.audit;
  WarehouseSessionStep _step = WarehouseSessionStep.pickMode;
  String? _sessionId;
  String? _sourceBarcode;
  int _scannedCount = 0;
  WarehouseSessionEndResult? _endResult;
  bool _busy = false;
  bool _connected = false;

  WarehouseRepository get _repo => ref.read(warehouseRepositoryProvider);

  final List<WarehouseMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _scrollController.dispose();
    _scanFocus.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final healthy = await _repo.checkHealth();
    if (!mounted) return;
    setState(() => _connected = healthy);
    if (healthy) {
      _pushMessage(
        WarehouseMessageTone.system,
        'Ready — scan a barcode or type below',
      );
    } else {
      _pushMessage(
        WarehouseMessageTone.error,
        'Cannot reach MCP server',
        detail: 'Start mcp-server on port 3001',
      );
    }
  }

  void _pushMessage(
    WarehouseMessageTone tone,
    String text, {
    String? detail,
  }) {
    setState(() {
      _messages.add(WarehouseMessage(tone: tone, text: text, detail: detail));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetSession() {
    setState(() {
      _step = _mode == WarehouseScanMode.audit
          ? WarehouseSessionStep.pickMode
          : WarehouseSessionStep.scanSource;
      _sessionId = null;
      _sourceBarcode = null;
      _scannedCount = 0;
      _endResult = null;
      _busy = false;
    });
  }

  void _setMode(WarehouseScanMode mode) {
    setState(() {
      _mode = mode;
      _messages.clear();
      _resetSession();
    });
    final hint = switch (mode) {
      WarehouseScanMode.audit =>
        'Audit mode — scan a container only (e.g. TRAY-004)',
      WarehouseScanMode.dispatch =>
        'Dispatch — cart to truck, scan every serial',
      WarehouseScanMode.stockReturn =>
        'Return — truck to cart, scan every serial',
    };
    _pushMessage(WarehouseMessageTone.system, hint);
    _focusScan();
  }

  String _stepPrompt() {
    if (_mode == WarehouseScanMode.audit) {
      return 'Scan a container barcode (e.g. TRAY-004, CART-012)';
    }
    return switch (_step) {
      WarehouseSessionStep.scanSource => _mode == WarehouseScanMode.stockReturn
          ? 'Scan the truck barcode first (e.g. TRUCK-1)'
          : 'Scan the source cart or tray barcode',
      WarehouseSessionStep.scanDestination => _mode == WarehouseScanMode.stockReturn
          ? 'Scan the destination cart or tray'
          : 'Scan the destination truck (e.g. TRUCK-1)',
      WarehouseSessionStep.scanItems =>
        'Scan every item serial — Enter after each scan',
      WarehouseSessionStep.review =>
        'Review the list, then confirm or scan more',
      _ => 'Choose a mode above, then scan',
    };
  }

  void _focusScan() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scanFocus.requestFocus();
    });
  }

  Future<void> _submitScan(String raw) async {
    final barcode = raw.trim();
    if (barcode.isEmpty || _busy) return;
    _scanController.clear();
    setState(() => _busy = true);

    try {
      if (_mode == WarehouseScanMode.audit) {
        _pushMessage(WarehouseMessageTone.system, 'Scanning $barcode…');
        final result = await _repo.auditContainer(barcode);
        _renderAuditResult(result);
      } else {
        await _handleSessionScan(barcode);
      }
    } catch (e) {
      _pushMessage(WarehouseMessageTone.error, handleAppError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
      _focusScan();
    }
  }

  void _renderAuditResult(WarehouseAuditResult result) {
    final gaps = [
      ...result.missing.map((g) => 'Missing ${g.delta}× ${g.itemCode}'),
      ...result.surplus.map((g) => 'Extra ${g.delta}× ${g.itemCode}'),
    ];

    if (gaps.isEmpty) {
      _pushMessage(
        WarehouseMessageTone.ok,
        '${result.label} — all good',
        detail: 'Counts match what should be on this container.',
      );
    } else {
      _pushMessage(
        WarehouseMessageTone.warn,
        '${result.label} — needs attention',
        detail: gaps.join('\n'),
      );
    }

    for (final line in result.notTrackedV1) {
      _pushMessage(
        WarehouseMessageTone.muted,
        '${line.qty}× ${line.itemCode}',
        detail: 'Not tracked in V1 — informational only',
      );
    }
  }

  Future<void> _handleSessionScan(String barcode) async {
    if (_step == WarehouseSessionStep.scanSource) {
      setState(() {
        _sourceBarcode = barcode;
        _step = WarehouseSessionStep.scanDestination;
      });
      _pushMessage(WarehouseMessageTone.ok, 'Source: $barcode');
      return;
    }

    if (_step == WarehouseSessionStep.scanDestination) {
      final source = _sourceBarcode;
      if (source == null) {
        _pushMessage(WarehouseMessageTone.error, 'Scan the source first');
        return;
      }

      _pushMessage(WarehouseMessageTone.ok, 'Destination: $barcode');

      final modeStr =
          _mode == WarehouseScanMode.dispatch ? 'dispatch' : 'return';
      final started = await _repo.startSession(
        mode: modeStr,
        sourceBarcode: source,
        destinationBarcode: barcode,
      );

      setState(() {
        _sessionId = started.sessionId;
        _step = WarehouseSessionStep.scanItems;
        _scannedCount = 0;
      });

      _pushMessage(
        WarehouseMessageTone.system,
        '${started.sourceLabel} → ${started.destinationLabel}',
        detail: '${started.expectedAudited.length} item types expected',
      );
      for (final line in started.notTrackedV1) {
        _pushMessage(
          WarehouseMessageTone.muted,
          '${line.qty}× ${line.itemCode}',
          detail: 'Not tracked in V1',
        );
      }
      return;
    }

    if (_step == WarehouseSessionStep.scanItems) {
      final sessionId = _sessionId;
      if (sessionId == null) {
        _pushMessage(
          WarehouseMessageTone.error,
          'Session not started — scan source and destination first',
        );
        return;
      }

      final result = await _repo.scanSerial(
        sessionId: sessionId,
        serial: barcode,
      );
      if (result.duplicate) {
        _pushMessage(WarehouseMessageTone.warn, '$barcode already scanned');
      } else {
        setState(() => _scannedCount = result.scannedCount);
        _pushMessage(
          WarehouseMessageTone.ok,
          barcode,
          detail: result.itemCode,
        );
      }
      return;
    }

    _pushMessage(
      WarehouseMessageTone.error,
      'Tap Finish scanning or reset the session',
    );
  }

  Future<void> _handleEndSession() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    setState(() => _busy = true);

    try {
      final result = await _repo.endSession(sessionId);
      setState(() {
        _endResult = result;
        _step = WarehouseSessionStep.review;
      });
      _renderEndResult(result);
    } catch (e) {
      _pushMessage(WarehouseMessageTone.error, handleAppError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
      _focusScan();
    }
  }

  void _renderEndResult(WarehouseSessionEndResult result) {
    if (result.complete) {
      _pushMessage(
        WarehouseMessageTone.ok,
        'Session complete',
        detail: '${result.scanned.length} items scanned — ready to confirm.',
      );
      return;
    }

    final parts = <String>[
      if (result.missing.isNotEmpty)
        'Under-packed: ${result.missing.map((g) => '${g.delta}× ${g.itemCode}').join(', ')}',
      if (result.unexpected.isNotEmpty)
        'Unexpected: ${result.unexpected.map((e) => e.serial).join(', ')}',
    ];
    _pushMessage(
      WarehouseMessageTone.warn,
      'Gaps found',
      detail: parts.join('\n'),
    );
  }

  Future<void> _handleConfirm({required bool proceedAnyway, String? reason}) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    setState(() => _busy = true);

    try {
      final result = await _repo.confirmSession(
        sessionId: sessionId,
        proceedAnyway: proceedAnyway,
        reason: reason,
      );
      final moved = result.itemsMoved.fold<num>(0, (sum, row) => sum + row.qty);
      _pushMessage(
        WarehouseMessageTone.ok,
        'Transfer recorded',
        detail:
            'Stock entry ${result.stockEntryId} — $moved items moved',
      );
      setState(() => _step = WarehouseSessionStep.done);
    } catch (e) {
      _pushMessage(WarehouseMessageTone.error, handleAppError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
      _focusScan();
    }
  }

  Future<void> _showProceedDialog() async {
    final endResult = _endResult;
    if (endResult == null) return;

    final reasonCtrl = TextEditingController();
    final missingText = endResult.missing
        .map((g) => '${g.delta}× ${g.itemCode}')
        .join(', ');

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        title: const Text('Proceed anyway?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              missingText.isNotEmpty
                  ? 'Missing $missingText. Load anyway?'
                  : 'Unexpected items were scanned. Load anyway?',
              style: const TextStyle(color: Color(0xFF9999AA)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. arm left on truck intentionally',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Go back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Proceed anyway'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await _handleConfirm(
        proceedAnyway: true,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
    }
    reasonCtrl.dispose();
  }

  Future<void> _openCameraScan() async {
    final barcode = await context.push<String>('/scanner');
    if (barcode != null && barcode.isNotEmpty) {
      await _submitScan(barcode);
    }
    _focusScan();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(scheme),
            _buildModeRow(scheme),
            Expanded(child: _buildChatLog()),
            _buildScanDock(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LIGHTBENDERS WAREHOUSE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (_connected ? scheme.primary : scheme.error)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (_connected ? scheme.primary : scheme.error)
                    .withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: _connected ? scheme.primary : scheme.error,
                ),
                const SizedBox(width: 6),
                Text(
                  _connected ? 'Connected' : 'Offline',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _connected ? scheme.primary : scheme.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeRow(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          _modeChip('Audit', WarehouseScanMode.audit, scheme),
          const SizedBox(width: 8),
          _modeChip('Dispatch', WarehouseScanMode.dispatch, scheme),
          const SizedBox(width: 8),
          _modeChip('Return', WarehouseScanMode.stockReturn, scheme),
        ],
      ),
    );
  }

  Widget _modeChip(String label, WarehouseScanMode mode, ColorScheme scheme) {
    final active = _mode == mode;
    return Expanded(
      child: Material(
        color: active
            ? scheme.primary.withValues(alpha: 0.15)
            : const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: _busy ? null : () => _setMode(mode),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? scheme.primary : const Color(0xFF252533),
                width: active ? 1.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatLog() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _MessageBubble(message: msg);
      },
    );
  }

  Widget _buildScanDock(ColorScheme scheme) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A24),
        border: Border(top: BorderSide(color: Color(0xFF252533))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _stepPrompt(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _scanController,
                  focusNode: _scanFocus,
                  enabled: !_busy && _connected,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'Scan here…',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      onPressed: _busy || !_connected ? null : _openCameraScan,
                      tooltip: 'Camera scan',
                    ),
                  ),
                  onSubmitted: _submitScan,
                ),
              ),
            ],
          ),
          if (_scannedCount > 0 && _step == WarehouseSessionStep.scanItems)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '$_scannedCount scanned',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 12),
          _buildActions(scheme),
        ],
      ),
    );
  }

  Widget _buildActions(ColorScheme scheme) {
    if (_mode == WarehouseScanMode.audit) {
      return OutlinedButton(
        onPressed: _busy
            ? null
            : () {
                setState(() => _messages.clear());
                _pushMessage(WarehouseMessageTone.system, 'Audit cleared');
              },
        child: const Text('Clear log'),
      );
    }

    if (_step == WarehouseSessionStep.scanItems) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _messages.clear());
                      _resetSession();
                      _pushMessage(WarehouseMessageTone.system, 'Session cleared');
                    },
              child: const Text('Start over'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _busy ? null : _handleEndSession,
              child: const Text('Finish scanning'),
            ),
          ),
        ],
      );
    }

    if (_step == WarehouseSessionStep.review && _endResult != null) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _step = WarehouseSessionStep.scanItems;
                        _endResult = null;
                      });
                      _pushMessage(
                        WarehouseMessageTone.system,
                        'Keep scanning — tap Finish when done',
                      );
                    },
              child: const Text('Scan more'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      if (_endResult?.complete == true) {
                        _handleConfirm(proceedAnyway: false);
                      } else {
                        _showProceedDialog();
                      }
                    },
              child: const Text('Confirm transfer'),
            ),
          ),
        ],
      );
    }

    if (_step == WarehouseSessionStep.done) {
      return FilledButton(
        onPressed: _busy
            ? null
            : () {
                setState(() => _messages.clear());
                _resetSession();
                _pushMessage(WarehouseMessageTone.system, 'Ready for next job');
              },
        child: const Text('New session'),
      );
    }

    return OutlinedButton(
      onPressed: _busy
          ? null
          : () {
              setState(() => _messages.clear());
              _resetSession();
              _pushMessage(WarehouseMessageTone.system, 'Reset');
            },
      child: const Text('Reset'),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final WarehouseMessage message;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData? icon) = switch (message.tone) {
      WarehouseMessageTone.ok => (
          const Color(0xFF1A3D2E),
          const Color(0xFF6EE7A0),
          Icons.check_circle_outline_rounded,
        ),
      WarehouseMessageTone.warn => (
          const Color(0xFF3D3018),
          const Color(0xFFE8A838),
          Icons.warning_amber_rounded,
        ),
      WarehouseMessageTone.error => (
          const Color(0xFF3D1818),
          const Color(0xFFFF5252),
          Icons.error_outline_rounded,
        ),
      WarehouseMessageTone.muted => (
          const Color(0xFF252533),
          const Color(0xFF9999AA),
          null,
        ),
      WarehouseMessageTone.system => (
          const Color(0xFF1A1A24),
          const Color(0xFF9999AA),
          null,
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            if (message.detail != null) ...[
              const SizedBox(height: 6),
              Text(
                message.detail!,
                style: TextStyle(
                  color: fg.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
