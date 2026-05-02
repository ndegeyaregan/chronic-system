import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../core/money.dart';
import '../../models/preauth.dart';
import '../../widgets/common/empty_state.dart';
import 'preauth_list_screen.dart' show preauthStatusColor;

class PreauthDetailScreen extends StatelessWidget {
  final String id;
  final Preauth? preauth;

  const PreauthDetailScreen({super.key, required this.id, this.preauth});

  @override
  Widget build(BuildContext context) {
    if (preauth == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pre-Authorisation')),
        body: const EmptyState(
          icon: Icons.assignment_outlined,
          title: 'Not found',
          subtitle: 'Pre-authorisation details could not be loaded.',
        ),
      );
    }

    final p = preauth!;
    final color = preauthStatusColor(p.status);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: kPrimaryGradient),
        ),
        title: const Text(
          'Pre-Authorisation',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusBanner(preauth: p, color: color),
          const SizedBox(height: 16),
          _AmountCard(preauth: p),
          if (p.insurerNote.isNotEmpty) ...[
            const SizedBox(height: 16),
            _NoteCard(
              icon: Icons.info_outline,
              color: color,
              title: 'Insurer note',
              body: p.insurerNote,
            ),
          ],
          const SizedBox(height: 16),
          _DetailCard(children: [
            if (p.diagnosis.isNotEmpty)
              _DetailRow(label: 'Diagnosis', value: p.diagnosis),
            if (p.symptoms.isNotEmpty)
              _DetailRow(label: 'Symptoms', value: p.symptoms),
            if (p.requestType.isNotEmpty)
              _DetailRow(label: 'Type', value: p.requestType),
            _DetailRow(label: 'Claim No', value: p.claimNo),
            if (p.authCode.isNotEmpty)
              _DetailRow(label: 'Auth Code', value: p.authCode),
            _DetailRow(label: 'Member No', value: p.memberNo),
            if (p.memberName.isNotEmpty)
              _DetailRow(label: 'Member', value: p.memberName),
            if (p.requestDate != null)
              _DetailRow(
                label: 'Request Date',
                value: DateFormat('dd MMM yyyy').format(p.requestDate!),
              ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Status banner
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final Preauth preauth;
  final Color color;
  const _StatusBanner({required this.preauth, required this.color});

  @override
  Widget build(BuildContext context) {
    final p = preauth;
    final title = p.description.isNotEmpty
        ? p.description
        : (p.diagnosis.isNotEmpty ? p.diagnosis : 'Pre-authorisation request');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: kPrimaryGradient,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kShadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(kRadiusFull),
                ),
                child: Text(
                  p.statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            p.claimNo,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          if (p.requestDate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Requested ${DateFormat('dd MMM yyyy').format(p.requestDate!)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Amounts card
// ─────────────────────────────────────────────────────────────────────────────

class _AmountCard extends StatelessWidget {
  final Preauth preauth;
  const _AmountCard({required this.preauth});

  @override
  Widget build(BuildContext context) {
    final p = preauth;
    final approved = p.approvedAmount;
    final requested = p.requestedAmount;
    final hasBoth = approved > 0 && requested > 0;
    final partial = hasBoth && approved < requested;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        boxShadow: kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _AmountTile(
                  label: 'Requested',
                  amount: requested,
                  color: kSubtext,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: kSubtext.withValues(alpha: 0.18),
              ),
              Expanded(
                child: _AmountTile(
                  label: 'Approved',
                  amount: approved,
                  color: approved > 0 ? kSuccess : kSubtext,
                ),
              ),
            ],
          ),
          if (partial) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kAccentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(kRadiusSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: kAccentAmber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Partial approval — ${(approved / requested * 100).round()}% of request approved.',
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: kAccentAmber,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _AmountTile({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 11.5, color: kSubtext, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        amount > 0
            ? Money(
                amount: amount,
                style: TextStyle(
                    fontSize: 16,
                    color: color,
                    fontWeight: FontWeight.w700),
              )
            : const Text('—',
                style: TextStyle(
                    fontSize: 16,
                    color: kSubtext,
                    fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Note card
// ─────────────────────────────────────────────────────────────────────────────

class _NoteCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _NoteCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                      fontSize: 13, color: kText, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generic detail card
// ─────────────────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadiusMd),
        boxShadow: kCardShadow,
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;

  const _DetailRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, color: kSubtext),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: kText,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
