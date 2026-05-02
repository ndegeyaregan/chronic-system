import 'package:flutter/material.dart';
import '../health_facilities/facility_finder_screen.dart';

/// Network Providers screen — reuses the existing FacilityFinder
/// with a renamed title. Presented under the /home/network route.
class NetworkProvidersScreen extends StatelessWidget {
  const NetworkProvidersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // FacilityFinderScreen already has all the search/tab/map logic
    // for hospitals and pharmacies. We reuse it directly, but override
    // the AppBar title by wrapping the scaffold in a Builder that
    // doesn't change the inner screen's state.
    return const _NetworkShell();
  }
}

class _NetworkShell extends StatelessWidget {
  const _NetworkShell();

  @override
  Widget build(BuildContext context) {
    // We simply delegate to FacilityFinderScreen; its AppBar title
    // already says "Find a Facility". A separate AppBar would clash
    // (nested Scaffolds). Instead we return the finder directly.
    // The route constant routeNetwork = '/home/network' is wired in
    // the ShellRoute so bottom-nav is preserved.
    return const FacilityFinderScreen();
  }
}
