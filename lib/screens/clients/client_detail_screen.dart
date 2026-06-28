import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/client_provider.dart';
import '../../core/error_handler.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_error.dart';

class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientDetailProvider(id));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Edit client',
            onPressed: () => context.push('/clients/$id/edit'),
          ),
        ],
      ),
      body: clientAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => AppError(
          message: handleAppError(e),
          onRetry: () => ref.invalidate(clientDetailProvider(id)),
        ),
        data: (client) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar + Name
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: scheme.primary.withValues(alpha: 0.12),
                    child: Text(
                      client.fullName.isNotEmpty
                          ? client.fullName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    client.fullName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _InfoCard(children: [
              if (client.phone != null)
                _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: client.phone!),
              if (client.email != null)
                _InfoRow(icon: Icons.email_rounded, label: 'Email', value: client.email!),
              if (client.idDocument != null)
                _InfoRow(
                    icon: Icons.badge_rounded,
                    label: 'ID / Document',
                    value: client.idDocument!),
              if (client.phone == null && client.email == null && client.idDocument == null)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'No contact details added',
                    style: TextStyle(color: Color(0xFF9999AA)),
                  ),
                ),
            ]),

            if (client.notes != null && client.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionLabel(label: 'Notes'),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A24),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF252533)),
                ),
                child: Text(
                  client.notes!,
                  style: const TextStyle(
                    color: Color(0xFFEEEEF5),
                    height: 1.6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF252533)),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE8A838), size: 18),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF9999AA), fontSize: 11)),
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFFEEEEF5),
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: const TextStyle(
          color: Color(0xFF9999AA),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );
}
