import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/client_provider.dart';
import '../../models/client.dart';
import '../../core/error_handler.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_error.dart';
import '../../widgets/app_empty.dart';
import '../../widgets/client_tile.dart';

class ClientListScreen extends ConsumerStatefulWidget {
  const ClientListScreen({super.key});

  @override
  ConsumerState<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends ConsumerState<ClientListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Add client',
            onPressed: () => context.push('/clients/new'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Color(0xFFEEEEF5)),
              decoration: InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9999AA)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Color(0xFF9999AA)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),

          // Client list
          Expanded(
            child: clientsAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => AppError(
                message: handleAppError(e),
                onRetry: () => ref.invalidate(clientListProvider),
              ),
              data: (clients) {
                final filtered = _query.isEmpty
                    ? clients
                    : clients
                        .where((c) =>
                            c.fullName.toLowerCase().contains(_query.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return AppEmpty(
                    icon: Icons.people_outline_rounded,
                    title: _query.isEmpty ? 'No clients yet' : 'No results',
                    subtitle: _query.isEmpty
                        ? 'Add your first client to get started'
                        : 'Try a different search term',
                  );
                }

                return RefreshIndicator(
                  color: const Color(0xFFE8A838),
                  onRefresh: () async => ref.invalidate(clientListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final client = filtered[i];
                      return ClientTile(
                        client: client,
                        onTap: () => context.push('/clients/${client.id}'),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clients/new'),
        backgroundColor: const Color(0xFFE8A838),
        foregroundColor: const Color(0xFF0F0F13),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
