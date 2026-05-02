import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/money.dart';
import '../../models/visit.dart';
import '../../models/visit_line.dart';
import '../../providers/auth_provider.dart';
import '../../providers/visits_provider.dart';
import '../../services/sanlam_api_service.dart';
import '../../widgets/common/loading_shimmer.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/claim_status_chip.dart';

class ClaimDetailScreen extends ConsumerStatefulWidget {
  final String visitId;
  final Visit? visit;
  final String memberNo;

  const ClaimDetailScreen({
    super.key,
    required this.visitId,
    this.visit,
    required this.memberNo,
  });

  @override
  ConsumerState<ClaimDetailScreen> createState() => _ClaimDetailScreenState();
}

class _ClaimDetailScreenState extends ConsumerState<ClaimDetailScreen> {
  late int _visitStatus = widget.visit?.visitStatus ?? 0;
  bool _updatingStatus = false;

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _setVisitStatus(int newStatus) async {
    if (_updatingStatus || _visitStatus == newStatus) return;
    final action = newStatus == 1 ? 'Agree' : 'Disagree';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action with this claim?'),
        content: Text(
          newStatus == 1
              ? 'You confirm that the services in this claim were rendered to you.'
              : 'You dispute this claim. Sanlam will follow up with the provider.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 1 ? kSuccess : kError,
              foregroundColor: Colors.white,
            ),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _updatingStatus = true);
    try {
      final loggedIn = ref.read(authProvider).member;
      final dash =
          (loggedIn?.memberNumber ?? widget.memberNo).lastIndexOf('-');
      final principalNo = dash == -1
          ? (loggedIn?.memberNumber ?? widget.memberNo)
          : '${(loggedIn?.memberNumber ?? widget.memberNo).substring(0, dash)}-00';
      final isPrincipal = widget.memberNo == principalNo;
      await sanlamApi.updateVisitStatus(
        memberNo: principalNo,
        visitId: widget.visitId,
        visitStatus: newStatus,
        dependentNo: isPrincipal ? null : widget.memberNo,
      );
      if (!mounted) return;
      setState(() => _visitStatus = newStatus);
      ref.invalidate(visitsProvider);
      ref.invalidate(familyVisitsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 1
              ? 'You agreed with this claim.'
              : 'You disagreed with this claim.'),
          backgroundColor: newStatus == 1 ? kSuccess : kError,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update: $e'),
          backgroundColor: kError,
        ),
      );
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final loggedIn = ref.read(authProvider).member;
      final dash =
          (loggedIn?.memberNumber ?? widget.memberNo).lastIndexOf('-');
      final principalNo = dash == -1
          ? (loggedIn?.memberNumber ?? widget.memberNo)
          : '${(loggedIn?.memberNumber ?? widget.memberNo).substring(0, dash)}-00';
      final isPrincipal = widget.memberNo == principalNo;
      final data = await sanlamApi.getVisitReport(
        principalNo,
        widget.visitId,
        dependantNo: isPrincipal ? null : widget.memberNo,
      );
      final fileData = data['filedata'] ?? data['FileData'] ?? '';
      if (fileData.toString().isEmpty) {
        throw Exception('Report data is empty');
      }
      final bytes = base64Decode(fileData.toString());
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'claim_${widget.visitId}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download report: $e'),
            backgroundColor: kError,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    final visitId = widget.visitId;
    final memberNo = widget.memberNo;
    final linesAsync = ref.watch(visitLinesProvider((memberNo, visitId)));

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text('Claim Detail',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _downloadPdf,
        icon: const Icon(Icons.download_outlined),
        label: const Text('Download PDF'),
        backgroundColor: kPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card with visit summary
          if (visit != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: kPrimaryGradient,
                borderRadius: BorderRadius.circular(kRadiusLg),
                boxShadow: kShadowMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.institution,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(visit.treatmentDate),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      ClaimStatusChip(status: visit.claimStatus),
                      Money(
                        amount: visit.totalAmount,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Claim No: ${visit.claimNo}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          if (visit != null) ...[
            const SizedBox(height: 16),
            _ConfirmationCard(
              status: _visitStatus,
              loading: _updatingStatus,
              onAgree: () => _setVisitStatus(1),
              onDisagree: () => _setVisitStatus(2),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Line Items',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kText,
            ),
          ),
          const SizedBox(height: 12),
          linesAsync.when(
            loading: () => const LoadingListCard(count: 4),
            error: (e, _) => EmptyState(
              icon: Icons.error_outline,
              title: 'Failed to load line items',
              subtitle: e.toString(),
              buttonLabel: 'Retry',
              onButton: () => ref.invalidate(
                  visitLinesProvider((memberNo, visitId))),
            ),
            data: (lines) {
              if (lines.isEmpty) {
                return const EmptyState(
                  icon: Icons.list_alt_outlined,
                  title: 'No line items',
                  subtitle: 'No detailed items found for this claim.',
                );
              }
              // Group by category
              final grouped = <String, List<VisitLine>>{};
              for (final line in lines) {
                grouped.putIfAbsent(line.category, () => []).add(line);
              }
              return Column(
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8),
                        child: Text(
                          entry.key.isNotEmpty
                              ? entry.key
                              : 'General',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kSubtext,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      ...entry.value.map((line) => _LineItemCard(line: line)),
                    ],
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _LineItemCard extends StatelessWidget {
  final VisitLine line;
  const _LineItemCard({required this.line});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        boxShadow: kShadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  line.serviceName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kText,
                  ),
                ),
              ),
              Money(
                amount: line.charge,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _SubDetail(label: 'San Price', amount: line.sanPrice),
              const SizedBox(width: 16),
              _SubDetail(
                  label: 'Benefit',
                  amount: line.benPlanAmount),
              const SizedBox(width: 16),
              _SubDetail(
                  label: 'Member Pays',
                  amount: line.memberPay),
            ],
          ),
          if (line.code.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Code: ${line.code}',
                style: const TextStyle(
                    fontSize: 10, color: kTextLight),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubDetail extends StatelessWidget {
  final String label;
  final double amount;
  const _SubDetail({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: kSubtext)),
        Money(
          amount: amount,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kText),
        ),
      ],
    );
  }
}

class _ConfirmationCard extends StatelessWidget {
  final int status;
  final bool loading;
  final VoidCallback onAgree;
  final VoidCallback onDisagree;

  const _ConfirmationCard({
    required this.status,
    required this.loading,
    required this.onAgree,
    required this.onDisagree,
  });

  @override
  Widget build(BuildContext context) {
    final agreed = status == 1;
    final disagreed = status == 2;
    final closed = status > 2;

    String header;
    Color headerColor;
    IconData headerIcon;
    if (agreed) {
      header = 'You agreed with this claim';
      headerColor = kSuccess;
      headerIcon = Icons.check_circle;
    } else if (disagreed) {
      header = 'You disputed this claim';
      headerColor = kError;
      headerIcon = Icons.report_gmailerrorred;
    } else if (closed) {
      header = 'Claim closed — confirmation no longer available';
      headerColor = kSubtext;
      headerIcon = Icons.lock_outline;
    } else {
      header = 'Did you receive these services?';
      headerColor = kText;
      headerIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kShadowSm,
        border: Border.all(
          color: headerColor.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon, color: headerColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  header,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: headerColor,
                  ),
                ),
              ),
            ],
          ),
          if (!closed) ...[
            const SizedBox(height: 6),
            const Text(
              'Help us catch fraud — confirm if these services were '
              'rendered to you, or dispute the claim.',
              style: TextStyle(fontSize: 12, color: kSubtext, height: 1.4),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: loading || disagreed ? null : onDisagree,
                    icon: const Icon(Icons.thumb_down_alt_outlined, size: 18),
                    label: const Text('Disagree'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kError,
                      side: BorderSide(
                        color: disagreed
                            ? kError
                            : kError.withValues(alpha: 0.4),
                        width: disagreed ? 2 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadiusMd),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: loading || agreed ? null : onAgree,
                    icon: loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.thumb_up_alt_outlined, size: 18),
                    label: Text(agreed ? 'Agreed' : 'Agree'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(kRadiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
