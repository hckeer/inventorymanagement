import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/dashboard_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_error.dart';
import '../../core/error_handler.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final scheme = Theme.of(context).colorScheme;

    final firstName = profileAsync.valueOrNull?.fullName.split(' ').first ?? '';

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: statsAsync.when(
          loading: () => const AppLoading(),
          error: (e, _) => AppError(
            message: handleSupabaseError(e),
            onRetry: () => ref.invalidate(dashboardStatsProvider),
          ),
          data: (stats) => CustomScrollView(
            slivers: [
              // ── Header ────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Film reel icon accent
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.movie_filter_rounded,
                              color: scheme.primary,
                              size: 22,
                            ),
                          ),
                          const Spacer(),
                          _SignOutButton(),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _greeting() + (firstName.isNotEmpty ? ', $firstName' : ''),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Here\'s your rental overview',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Stats Grid ────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                  ),
                  delegate: SliverChildListDelegate([
                    _StatCard(
                      label: 'Active Rentals',
                      value: '${stats.activeRentals}',
                      icon: Icons.handshake_outlined,
                      accentColor: const Color(0xFFE8A838),
                    ),
                    _StatCard(
                      label: 'Overdue',
                      value: '${stats.overdueRentals}',
                      icon: Icons.warning_amber_rounded,
                      accentColor: const Color(0xFFFF5252),
                    ),
                    _StatCard(
                      label: 'Available',
                      value: '${stats.availableEquipment}',
                      icon: Icons.check_circle_outline_rounded,
                      accentColor: const Color(0xFF4CAF50),
                    ),
                    _StatCard(
                      label: 'Revenue',
                      value: 'V2',
                      icon: Icons.bar_chart_rounded,
                      accentColor: const Color(0xFF9999AA),
                      muted: true,
                    ),
                  ]),
                ),
              ),

              // ── Quick Actions ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 8),
                  child: Text(
                    'Quick actions',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _QuickAction(
                      icon: Icons.receipt_long_rounded,
                      label: 'New Rental',
                      subtitle: 'Create a rental for a client',
                      onTap: () => context.push('/rentals/new'),
                    ),
                    const SizedBox(height: 10),
                    _QuickAction(
                      icon: Icons.videocam_rounded,
                      label: 'Add Equipment',
                      subtitle: 'Register a new item in inventory',
                      onTap: () => context.push('/equipment/new'),
                    ),
                    const SizedBox(height: 10),
                    _QuickAction(
                      icon: Icons.person_add_rounded,
                      label: 'Add Client',
                      subtitle: 'Add a new client to your database',
                      onTap: () => context.push('/clients/new'),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat Card ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.muted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF252533)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 17),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: muted ? const Color(0xFF9999AA) : accentColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9999AA),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Row ───────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: const Color(0xFF1A1A24),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF252533)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: scheme.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFEEEEF5),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9999AA),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9999AA),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sign Out Button ────────────────────────────────────────────────────────

class _SignOutButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.logout_rounded, color: Color(0xFF9999AA), size: 20),
      tooltip: 'Sign out',
      onPressed: () async {
        await ref.read(authRepositoryProvider).signOut();
      },
    );
  }
}
