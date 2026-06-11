import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../../core/constants.dart';
import '../../models/membership_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/co_pays_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/common/empty_state.dart';
import 'reprint_card_sheet.dart';
import '../../core/app_colors.dart';

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
      backgroundColor: context.c.bg,
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            children: [
              // Card sized by width, landscape aspect ratio (≈ credit card).
              LayoutBuilder(builder: (context, constraints) {
                // Width fills available space, clamped for large screens.
                final cardW = constraints.maxWidth.clamp(0.0, 440.0);
                // 1.55:1 — comfortably wider than tall, enough room for all
                // member details without clipping.
                final cardH = cardW / 1.55;
                return Center(
                  child: SizedBox(
                    width: cardW,
                    height: cardH,
                    child: RepaintBoundary(
                      key: _boundaryKey,
                      child: Consumer(builder: (_, ref, __) {
                        final corp =
                            ref.watch(corporateNameProvider).asData?.value;
                        return _CardWidget(card: card, corporateName: corp);
                      }),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 32),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sharing ? null : _shareCard,
                        icon: _sharing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
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
                        label: const Text(
                            'Request Card Reprint (UGX 20,000)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrimary,
                          side: const BorderSide(
                              color: kPrimary, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadiusMd),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _AuthorizationDocumentsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Card widget ────────────────────────────────────────────────────────────

class _CardWidget extends StatelessWidget {
  final MembershipCard card;
  final String? corporateName;
  const _CardWidget({required this.card, this.corporateName});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      final pad = w * 0.05;
      // QR fixed at 26% of card width — always visible but never dominant.
      final qrSize = w * 0.26;
      final logoH = h * 0.14;
      final chipW = w * 0.09;
      final chipH = chipW * 0.75;

      return Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF002E8A), Color(0xFF1A56C4), Color(0xFF0046BE)],
            stops: [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(w * 0.045),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF003DA5).withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(w * 0.045),
          child: Stack(
            children: [
              // ── Decorative background circles ──────────────────────────
              Positioned(
                right: -w * 0.18,
                top: -h * 0.35,
                child: _Circle(w * 0.55, 0.09),
              ),
              Positioned(
                right: w * 0.08,
                top: -h * 0.1,
                child: _Circle(w * 0.28, 0.06),
              ),
              Positioned(
                left: -w * 0.12,
                bottom: -h * 0.3,
                child: _Circle(w * 0.45, 0.07),
              ),
              Positioned.fill(
                child: Opacity(
                  opacity: 0.04,
                  child: CustomPaint(painter: _StripePainter()),
                ),
              ),

              // ── Card content ────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Logo + Relation pill
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/login_logo.png',
                          height: logoH,
                          fit: BoxFit.contain,
                        ),
                        const Spacer(),
                        _RelationPill(card.relation),
                      ],
                    ),

                    SizedBox(height: h * 0.05),

                    // Row 2: EMV chip + scheme / corp name
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _ChipIcon(width: chipW, height: chipH),
                        SizedBox(width: pad * 0.7),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                card.schemeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: h * 0.085,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              if ((corporateName?.trim().isNotEmpty ?? false))
                                Text(
                                  corporateName!.trim().toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: h * 0.062,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Row 3: Member details (left) + QR code (right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Left column — all member text fields
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _FieldLabel('MEMBER NAME', h),
                              const SizedBox(height: 2),
                              Text(
                                card.memberName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: h * 0.105,
                                  fontWeight: FontWeight.w700,
                                  height: 1.1,
                                ),
                              ),
                              SizedBox(height: h * 0.04),
                              _FieldLabel('MEMBER NO', h),
                              const SizedBox(height: 2),
                              // FittedBox guarantees the number is never clipped
                              // regardless of how long the member number is.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  card.memberNo,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: h * 0.1,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (card.planCode.isNotEmpty) ...[
                                SizedBox(height: h * 0.035),
                                _FieldLabel('PLAN', h),
                                const SizedBox(height: 2),
                                Text(
                                  card.planCode,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: h * 0.08,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        SizedBox(width: pad),

                        // Right: QR code
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: card.memberNo,
                            version: QrVersions.auto,
                            size: qrSize,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF002E8A),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF002E8A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Helper widgets ──────────────────────────────────────────────────────────

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle(this.size, this.opacity);

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );
}

class _RelationPill extends StatelessWidget {
  final String relation;
  const _RelationPill(this.relation);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Text(
          relation.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      );
}

/// Decorative EMV-style chip icon.
class _ChipIcon extends StatelessWidget {
  final double width;
  final double height;
  const _ChipIcon({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8C96B), Color(0xFFC9A227)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(width * 0.18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: CustomPaint(painter: _ChipPainter()),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final double cardH;
  const _FieldLabel(this.text, this.cardH);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          color: Colors.white54,
          fontSize: cardH * 0.062,
          letterSpacing: 1.0,
          fontWeight: FontWeight.w600,
        ),
      );
}

// ── Custom painters ─────────────────────────────────────────────────────────

/// Draws subtle diagonal stripes for card texture.
class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5;
    const spacing = 18.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Draws the contact lines on the EMV chip.
class _ChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFA07C1A).withValues(alpha: 0.7)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    // Horizontal lines
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
    // Vertical lines
    final midX = size.width / 2;
    canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), paint);
    // Outer rectangle inset
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.15, size.height * 0.15,
            size.width * 0.7, size.height * 0.7),
        Radius.circular(size.width * 0.1),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// ── Authorization Documents Section ─────────────────────────────────────────
// Shows documents issued to the member by the Sanlam admin team. Members can
// view/download each document. Documents are issued from the admin portal at
// /membership-authorizations.

class _AuthDoc {
  final String id;
  final String title;
  final String? description;
  final String fileUrl;
  final String? fileName;
  final String? mimeType;
  final DateTime issuedAt;

  _AuthDoc({
    required this.id,
    required this.title,
    required this.fileUrl,
    required this.issuedAt,
    this.description,
    this.fileName,
    this.mimeType,
  });

  factory _AuthDoc.fromJson(Map<String, dynamic> j) {
    final rawUrl =
        (j['file_url_abs'] ?? j['file_url'] ?? '').toString().trim();
    final absUrl = rawUrl.startsWith('http')
        ? rawUrl
        : '$kServerBase${rawUrl.startsWith('/') ? '' : '/'}$rawUrl';
    return _AuthDoc(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? 'Authorization Document').toString(),
      description: (j['description'] ?? '').toString().isEmpty
          ? null
          : j['description'].toString(),
      fileUrl: absUrl,
      fileName: (j['file_name'] ?? '').toString().isEmpty
          ? null
          : j['file_name'].toString(),
      mimeType: (j['mime_type'] ?? '').toString().isEmpty
          ? null
          : j['mime_type'].toString(),
      issuedAt: DateTime.tryParse((j['issued_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

class _AuthorizationDocumentsSection extends StatefulWidget {
  const _AuthorizationDocumentsSection();

  @override
  State<_AuthorizationDocumentsSection> createState() =>
      _AuthorizationDocumentsSectionState();
}

class _AuthorizationDocumentsSectionState
    extends State<_AuthorizationDocumentsSection> {
  late Future<List<_AuthDoc>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_AuthDoc>> _load() async {
    try {
      final res = await dio.get('/membership-authorizations/mine');
      final data = res.data;
      final list = (data is Map && data['documents'] is List)
          ? data['documents'] as List
          : (data is List ? data : const []);
      return list
          .whereType<Map>()
          .map((e) => _AuthDoc.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return <_AuthDoc>[];
    }
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _open(_AuthDoc d) async {
    final uri = Uri.tryParse(d.fileUrl);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open ${d.title}'),
          backgroundColor: kError,
        ),
      );
    }
  }

  IconData _iconFor(_AuthDoc d) {
    final mt = d.mimeType?.toLowerCase() ?? '';
    final name = (d.fileName ?? d.fileUrl).toLowerCase();
    if (mt.contains('pdf') || name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }
    if (mt.startsWith('image/') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp')) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_AuthDoc>>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        final docs = snap.data ?? const <_AuthDoc>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user_outlined,
                    size: 18, color: kPrimary),
                const SizedBox(width: 8),
                const Text(
                  'Authorization Documents',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kText,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, color: kSubtext),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Documents issued to you by the Sanlam team.',
              style: TextStyle(fontSize: 12, color: kSubtext),
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kPrimary),
                  ),
                ),
              )
            else if (docs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kSurfaceAlt,
                  borderRadius: BorderRadius.circular(kRadiusMd),
                  border: Border.all(color: kBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.folder_off_outlined,
                        size: 20, color: kSubtext),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No authorization documents yet.',
                        style: TextStyle(fontSize: 13, color: kSubtext),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: docs
                    .map((d) => _DocTile(
                          doc: d,
                          icon: _iconFor(d),
                          onTap: () => _open(d),
                        ))
                    .toList(),
              ),
          ],
        );
      },
    );
  }
}

class _DocTile extends StatelessWidget {
  final _AuthDoc doc;
  final IconData icon;
  final VoidCallback onTap;
  const _DocTile({required this.doc, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kBorder),
        boxShadow: kShadowSm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusMd),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: kPrimary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (doc.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          doc.description!,
                          style: const TextStyle(
                              fontSize: 12, color: kSubtext),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Issued ${DateFormat('dd MMM yyyy').format(doc.issuedAt)}',
                        style:
                            const TextStyle(fontSize: 11, color: kTextLight),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility_outlined,
                          size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'View',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
