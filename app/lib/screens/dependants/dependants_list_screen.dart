import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants.dart';
import '../../providers/dependants_provider.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/dependant_tile.dart';

const _kAddDependantsUrl =
    'http://sanlamallianz4u.co.ug/medicalform/index.php';

class DependantsListScreen extends ConsumerWidget {
  const DependantsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depAsync = ref.watch(dependantsProvider);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text('Dependants',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: depAsync.when(
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [LoadingListCard(count: 4)],
        ),
        error: (e, _) {
          // Treat "no dependants found" responses as a friendly empty state.
          final msg = e.toString().toLowerCase();
          if (msg.contains('no dependant') ||
              msg.contains('not found') ||
              msg.contains('no record')) {
            return _NoDependantsView(
              onRefresh: () async => ref.invalidate(dependantsProvider),
            );
          }
          return EmptyState(
            icon: Icons.group_outlined,
            title: 'Failed to load dependants',
            subtitle: e.toString(),
            buttonLabel: 'Retry',
            onButton: () => ref.invalidate(dependantsProvider),
          );
        },
        data: (deps) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dependantsProvider),
          child: deps.isEmpty
              ? _NoDependantsView(
                  onRefresh: () async => ref.invalidate(dependantsProvider),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: deps.length,
                  itemBuilder: (context, i) => DependantTile(
                    dependant: deps[i],
                    onTap: () => context.push(
                      '$routeDependants/${Uri.encodeComponent(deps[i].memberNo)}',
                      extra: deps[i],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _NoDependantsView extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _NoDependantsView({required this.onRefresh});

  Future<void> _openAddForm(BuildContext context) async {
    final uri = Uri.parse(_kAddDependantsUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the form')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        children: [
          const SizedBox(height: 40),
          Container(
            width: 84,
            height: 84,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.group_outlined,
                size: 42, color: kPrimary),
          ),
          const Text(
            'No dependants found',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: kText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You don’t have any dependants registered on your policy yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kSubtext, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(kRadiusMd),
              border: Border.all(color: kPrimary.withValues(alpha: 0.25)),
              boxShadow: kCardShadow,
            ),
            child: Column(
              children: [
                const Text(
                  'Want to add dependants to your scheme?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Click here to add dependants'),
                    onPressed: () => _openAddForm(context),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You will be taken to our online registration form.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kSubtext, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
