import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/member_type_provider.dart';
import '../../core/constants.dart';

class ChronicOnly extends ConsumerWidget {
  final Widget child;

  const ChronicOnly({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isChronic = ref.watch(isChronicMemberProvider);
    if (isChronic) return child;
    return _NotAvailableScreen();
  }
}

class _NotAvailableScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.health_and_safety_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'This area is only available for members enrolled in Chronic Care',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(routeDashboard),
                child: const Text('Go to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
