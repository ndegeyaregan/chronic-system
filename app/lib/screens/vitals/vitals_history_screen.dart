import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants.dart';
import '../../providers/vitals_provider.dart';
import '../../widgets/common/loading_shimmer.dart';

class VitalsHistoryScreen extends ConsumerWidget {
  const VitalsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(vitalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Vitals History')),
      body: state.isLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingListCard(count: 5),
            )
          : state.vitals.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          color: Color(0xFFCBD5E1), size: 64),
                      SizedBox(height: 16),
                      Text('No vitals history yet',
                          style: TextStyle(color: kSubtext, fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.vitals.length,
                  itemBuilder: (context, i) {
                    final v = state.vitals[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 14, color: kSubtext),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd MMM yyyy, HH:mm')
                                    .format(v.loggedAt),
                                style: const TextStyle(
                                    fontSize: 12, color: kSubtext),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (v.bloodSugar != null)
                                _chip('🩸 ${v.bloodSugar!.toStringAsFixed(1)} mmol/L',
                                    v.bloodSugar! > 10 ? kError : kSuccess),
                              if (v.systolicBP != null)
                                _chip(
                                    '❤️ ${v.systolicBP}/${v.diastolicBP} mmHg',
                                    v.systolicBP! > 140 ? kError : kSuccess),
                              if (v.heartRate != null)
                                _chip('🫀 ${v.heartRate} bpm',
                                    v.heartRate! > 100 ? kError : kSuccess),
                              if (v.weight != null)
                                _chip('⚖️ ${v.weight!.toStringAsFixed(1)} kg',
                                    kPrimary),
                              if (v.oxygenSaturation != null)
                                _chip(
                                    '💨 ${v.oxygenSaturation!.toInt()}% O₂',
                                    v.oxygenSaturation! < 94
                                        ? kError
                                        : kSuccess),
                              if (v.mood != null)
                                _chip('😊 ${v.mood}', kAccent),
                              if (v.painLevel != null)
                                _chip('😣 Pain ${v.painLevel}/10',
                                    v.painLevel! <= 3 ? kSuccess : kWarning),
                            ],
                          ),
                          if (v.notes != null && v.notes!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              v.notes!,
                              style: const TextStyle(
                                  fontSize: 12, color: kSubtext),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
