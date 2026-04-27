import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants.dart';
import '../../widgets/common/bottom_nav.dart';
import '../../widgets/common/floating_chat.dart';

class HomeScreen extends ConsumerWidget {
  final Widget child;

  const HomeScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        children: [
          child,
          const FloatingChat(),
        ],
      ),
      bottomNavigationBar: const BottomNav(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'sos_fab',
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        onPressed: () => context.push(routeEmergencySos),
        tooltip: 'Emergency SOS',
        child: const Icon(Icons.emergency_rounded, size: 28),
      ),
    );
  }
}
