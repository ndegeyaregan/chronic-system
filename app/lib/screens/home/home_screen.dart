import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    );
  }
}
