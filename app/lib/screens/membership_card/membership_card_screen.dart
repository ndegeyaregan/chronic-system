import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../core/constants.dart';
import '../../models/membership_card.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/empty_state.dart';
import 'reprint_card_sheet.dart';

class MembershipCardScreen extends ConsumerStatefulWidget {
  const MembershipCardScreen({super.key});

  @override
  ConsumerState<MembershipCardScreen> createState() =>
      _MembershipCardScreenState();
}

class _MembershipCardScreenState
    extends ConsumerState<MembershipCardScreen> {
  final _boundaryKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareCard() async {
    setState(() => _sharing = true);
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/membership_card.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My Sanlam Membership Card',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share card: $e'),
            backgroundColor: kError,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = ref.watch(authProvider).member;
    if (member == null) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.credit_card_off_outlined,
          title: 'Not signed in',
          subtitle: 'Please sign in to view your membership card.',
        ),
      );
    }

    final card = MembershipCard.fromMember(member);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text('Membership Card',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'My Reprint Requests',
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () => context.push(routeCardReprintHistory),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RepaintBoundary(
                key: _boundaryKey,
                child: _CardWidget(card: card),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : _shareCard,
                  icon: _sharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                      : const Icon(Icons.share_outlined),
                  label: Text(_sharing ? 'Sharing…' : 'Share Card'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showReprintCardSheet(context),
                  icon: const Icon(Icons.credit_card_outlined),
                  label: const Text('Request Card Reprint (UGX 20,000)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final MembershipCard card;
  const _CardWidget({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: kPrimaryGradient,
        borderRadius: BorderRadius.circular(kRadiusXl),
        boxShadow: kShadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo / wordmark
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SANLAM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(kRadiusFull),
                ),
                child: Text(
                  card.relation.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            card.memberName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.memberNo,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              letterSpacing: 1.5,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SCHEME',
                      style: TextStyle(
                          color: Colors.white60, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.schemeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (card.planCode.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'PLAN',
                        style: TextStyle(
                            color: Colors.white60, fontSize: 10),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.planCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              QrImageView(
                data: card.memberNo,
                version: QrVersions.auto,
                size: 80,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF003DA5),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF003DA5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
