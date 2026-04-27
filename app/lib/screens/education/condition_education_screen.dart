import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../providers/member_provider.dart';
import '../../providers/education_provider.dart';
import '../../utils/content_mapper.dart';
import '../../services/cms_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────
class ConditionInfo {
  final String title;
  final String emoji;
  final String whatIsIt;
  final List<String> warningSigns;
  final List<String> dietTips;
  final List<String> lifestyleTips;
  final List<String> medicationTips;
  final String whenToSeekHelp;

  const ConditionInfo({
    required this.title,
    required this.emoji,
    required this.whatIsIt,
    required this.warningSigns,
    required this.dietTips,
    required this.lifestyleTips,
    required this.medicationTips,
    required this.whenToSeekHelp,
  });
}

const Map<String, ConditionInfo> _conditionContent = {
  'hypertension': ConditionInfo(
    title: 'Hypertension / High Blood Pressure',
    emoji: '🩺',
    whatIsIt:
        'Hypertension is a chronic condition where the force of blood against artery walls is consistently too high. '
        'Often called "the silent killer" as it rarely has noticeable symptoms until serious complications arise.',
    warningSigns: [
      'Severe headache',
      'Chest pain or tightness',
      'Vision changes or blurriness',
      'Shortness of breath',
      'Sudden nosebleed',
    ],
    dietTips: [
      'Reduce salt to less than 6g per day',
      'Eat potassium-rich foods (bananas, sweet potatoes)',
      'Avoid processed and packaged foods',
      'Limit alcohol consumption',
      'Follow the DASH diet — more vegetables and whole grains',
    ],
    lifestyleTips: [
      'Exercise at least 30 minutes most days',
      'Maintain a healthy weight',
      'Quit smoking — it raises blood pressure significantly',
      'Manage stress with breathing exercises or yoga',
      'Limit caffeine intake',
    ],
    medicationTips: [
      'Take BP medication at the same time every day — even when you feel fine',
      'Never stop BP medication suddenly without consulting your doctor',
      'Monitor BP at home and keep a log',
      'Report any side effects (dizziness, swelling) to your doctor',
    ],
    whenToSeekHelp:
        'Seek immediate help if systolic BP >180 or diastolic >120, or if you experience severe headache, chest pain, or sudden vision changes.',
  ),
  'diabetes': ConditionInfo(
    title: 'Diabetes (Type 1 & Type 2)',
    emoji: '🩸',
    whatIsIt:
        'Diabetes is a condition where blood glucose is too high. '
        'Type 2 means the body doesn\'t use insulin effectively; Type 1 means the body produces no insulin. '
        'Both require careful management to prevent complications.',
    warningSigns: [
      'Excessive thirst or frequent urination',
      'Blurred vision',
      'Slow-healing wounds or cuts',
      'Tingling or numbness in feet or hands',
      'Unexplained fatigue',
    ],
    dietTips: [
      'Choose low glycaemic index (GI) foods',
      'Control portion sizes at every meal',
      'Avoid sugary drinks and sweets',
      'Eat regularly — never skip meals',
      'Include fibre-rich vegetables at every meal',
    ],
    lifestyleTips: [
      'Regular moderate exercise lowers blood sugar naturally',
      'Check your feet daily for wounds or blisters',
      'Manage stress — it can raise blood sugar levels',
      'Get regular eye and kidney check-ups annually',
    ],
    medicationTips: [
      'Take insulin or tablets exactly as prescribed — never skip doses',
      'Always carry fast-acting sugar (glucose tablets) for hypoglycaemia',
      'Keep a glucose meter handy and test regularly',
      'Know the signs of low blood sugar: shaking, sweating, confusion',
    ],
    whenToSeekHelp:
        'Seek help if blood sugar <3.9 or >15 mmol/L, symptoms of DKA (nausea, fruity breath, vomiting), or if a hypoglycaemic episode does not improve.',
  ),
  'heart': ConditionInfo(
    title: 'Heart Disease / Coronary Artery Disease',
    emoji: '❤️',
    whatIsIt:
        'Coronary artery disease is the narrowing of the arteries that supply blood to the heart, '
        'reducing blood flow and oxygen delivery. It is the leading cause of heart attacks worldwide.',
    warningSigns: [
      'Chest pain or pressure (angina)',
      'Shortness of breath during activity or at rest',
      'Heart palpitations or irregular heartbeat',
      'Dizziness or light-headedness',
      'Pain radiating to arm, jaw, neck, or back',
    ],
    dietTips: [
      'Follow a heart-healthy Mediterranean-style diet',
      'Reduce saturated fats — limit red meat and full-fat dairy',
      'Avoid trans fats entirely (check food labels)',
      'Eat oily fish (salmon, sardines) at least twice weekly',
      'Increase omega-3 rich foods — walnuts, flaxseeds',
    ],
    lifestyleTips: [
      'Complete cardiac rehabilitation if prescribed by your doctor',
      'Engage in gentle daily activity as approved by your cardiologist',
      'No smoking — smoking doubles the risk of heart attack',
      'Manage stress through meditation or relaxation techniques',
      'Monitor blood pressure and cholesterol regularly',
    ],
    medicationTips: [
      'Take statins, blood thinners, and beta-blockers exactly as prescribed',
      'Never miss a dose of antiplatelet medication (e.g. aspirin)',
      'Carry GTN spray if prescribed — use for chest pain episodes',
      'Report any unusual bleeding or bruising to your doctor',
    ],
    whenToSeekHelp:
        'CALL EMERGENCY IMMEDIATELY if you experience chest pain lasting more than 15 minutes, crushing pressure in the chest, or chest pain accompanied by sweating and vomiting.',
  ),
  'copd': ConditionInfo(
    title: 'COPD / Asthma',
    emoji: '💨',
    whatIsIt:
        'COPD (Chronic Obstructive Pulmonary Disease) is irreversible lung damage causing progressive breathing difficulty. '
        'Asthma is a reversible narrowing of the airways triggered by allergens, exercise, or irritants.',
    warningSigns: [
      'Increased breathlessness during daily activities',
      'Change in sputum colour (yellow/green) or increased quantity',
      'Chest tightness or wheezing',
      'Waking at night due to cough',
      'Reduced exercise tolerance',
    ],
    dietTips: [
      'Maintain a healthy weight — obesity worsens breathing',
      'Eat small, frequent meals (large meals restrict diaphragm movement)',
      'Stay well hydrated to help thin mucus secretions',
      'Include anti-inflammatory foods like berries and leafy greens',
    ],
    lifestyleTips: [
      'Avoid triggers: smoke, dust, pollen, cold air, strong perfumes',
      'Use your preventer inhaler regularly as prescribed',
      'Get flu and pneumococcal vaccinations annually',
      'Practice breathing exercises taught by your physiotherapist',
    ],
    medicationTips: [
      'Never skip your preventer inhaler — it reduces inflammation daily',
      'Use your reliever inhaler only for acute attacks, not as daily medication',
      'Correct inhaler technique is essential — ask your pharmacist to check',
      'Keep your reliever inhaler accessible at all times',
    ],
    whenToSeekHelp:
        'Seek immediate help if O₂ saturation <92%, rescue inhaler is not helping, you have severe breathlessness at rest, or your lips or fingernails appear bluish.',
  ),
  'kidney': ConditionInfo(
    title: 'Kidney Disease (CKD)',
    emoji: '🫘',
    whatIsIt:
        'Chronic Kidney Disease (CKD) is the gradual loss of kidney function over time. '
        'The kidneys filter waste products and excess fluid from the blood — when they fail, toxins accumulate.',
    warningSigns: [
      'Swollen ankles, feet, or face (fluid retention)',
      'Decreased urine output or foamy urine',
      'Persistent fatigue and weakness',
      'Nausea and loss of appetite',
      'Shortness of breath or confusion',
    ],
    dietTips: [
      'Restrict salt intake strictly',
      'Limit potassium-rich foods: bananas, oranges, potatoes, tomatoes',
      'Limit phosphorus: reduce dairy, nuts, and cola drinks',
      'Moderate protein intake as advised by your dietitian',
      'Follow fluid restriction advice from your doctor carefully',
    ],
    lifestyleTips: [
      'Control blood pressure and blood sugar strictly — they protect kidneys',
      'Avoid NSAIDs (ibuprofen, aspirin) — they damage kidney function',
      'Maintain a healthy weight and quit smoking',
      'Get regular kidney function tests (eGFR, creatinine)',
    ],
    medicationTips: [
      'Take blood pressure and phosphate binder medications as prescribed',
      'Avoid any nephrotoxic (kidney-damaging) drugs without doctor approval',
      'Inform all doctors about your kidney condition before any new medication',
      'Schedule regular kidney function tests as advised',
    ],
    whenToSeekHelp:
        'Seek immediate help if there is a sudden decrease in urine output, severe swelling that worsens rapidly, confusion, or shortness of breath at rest.',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ConditionEducationScreen extends ConsumerWidget {
  const ConditionEducationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberState = ref.watch(memberProvider);
    final eduState = ref.watch(educationContentProvider);
    final member = memberState.member;
    final conditions = member?.conditions ?? [];

    // Fetch education content when conditions change
    ref.listen(memberProvider, (prev, next) {
      if (next.member?.conditions != prev?.member?.conditions) {
        final conditionIds = next.member?.conditions ?? [];
        if (conditionIds.isNotEmpty) {
          ref.read(educationContentProvider.notifier).fetchEducationContent(
              conditionIds
                  .map((c) => c.toLowerCase())
                  .toList());
        }
      }
    });

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF001A5C), Color(0xFF003DA5)],
            ),
          ),
        ),
        title: const Text('Health Education',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _buildBody(context, ref, conditions, eduState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<String> conditions,
    EducationContentState eduState,
  ) {
    if (eduState.isLoading && eduState.conditions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Loading education content...'),
          ],
        ),
      );
    }

    if (eduState.error != null && eduState.conditions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              eduState.error ?? 'Failed to load content',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (conditions.isNotEmpty) {
                  ref
                      .read(educationContentProvider.notifier)
                      .fetchEducationContent(
                          conditions.map((c) => c.toLowerCase()).toList());
                }
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final conditionList = eduState.conditions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // ── Intro banner ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(kRadiusMd),
            border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  color: kPrimary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  conditionList.isEmpty
                      ? 'General health education to help you live well every day.'
                      : 'Condition-specific guidance tailored to your health profile.',
                  style: const TextStyle(
                      fontSize: 13, color: kText, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Condition cards ──────────────────────────────────────────────
        if (conditionList.isEmpty)
          _GeneralWellnessCard()
        else ...[
          ...conditionList.map((info) => _ConditionCard(info: info)),
          const SizedBox(height: 8),
          _GeneralWellnessCard(),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CONDITION CARD (Expandable)
// ─────────────────────────────────────────────────────────────────────────────
class _ConditionCard extends StatefulWidget {
  final ConditionInfoData info;

  const _ConditionCard({required this.info});

  @override
  State<_ConditionCard> createState() => _ConditionCardState();
}

class _ConditionCardState extends State<_ConditionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(kRadiusLg),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                    child: Center(
                      child: Text(widget.info.emoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.info.title,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kText)),
                        const SizedBox(height: 2),
                        Text(
                            _expanded
                                ? 'Tap to collapse'
                                : 'Tap to learn more',
                            style: const TextStyle(
                                fontSize: 11, color: kSubtext)),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kSubtext,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded content ─────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('📋 What is it?',
                      [widget.info.whatIsIt], isText: true),
                  const SizedBox(height: 14),
                  _section('⚠️ Warning Signs', widget.info.warningSigns),
                  const SizedBox(height: 14),
                  _section('🥗 Diet Recommendations', widget.info.dietTips),
                  const SizedBox(height: 14),
                  _section('🏃 Lifestyle Tips', widget.info.lifestyleTips),
                  const SizedBox(height: 14),
                  _section('💊 Medication Tips', widget.info.medicationTips),
                  const SizedBox(height: 14),
                  _urgentSection(widget.info.whenToSeekHelp),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title, List<String> items, {bool isText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kText)),
        const SizedBox(height: 8),
        if (isText)
          Text(items.first,
              style: const TextStyle(
                  fontSize: 13, color: kSubtext, height: 1.5))
        else
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 5),
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item,
                          style: const TextStyle(
                              fontSize: 13,
                              color: kSubtext,
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
      ],
    );
  }

  Widget _urgentSection(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kError.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(kRadiusMd),
        border: Border.all(color: kError.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.local_hospital_rounded,
              color: kError, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🏥 When to Seek Help',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kError)),
                const SizedBox(height: 4),
                Text(text,
                    style: const TextStyle(
                        fontSize: 12, color: kText, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  GENERAL WELLNESS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _GeneralWellnessCard extends StatefulWidget {
  @override
  State<_GeneralWellnessCard> createState() => _GeneralWellnessCardState();
}

class _GeneralWellnessCardState extends State<_GeneralWellnessCard> {
  bool _expanded = false;

  static const _tips = [
    '💧 Drink at least 8 glasses of water daily to support kidney function and energy.',
    '🚶 Aim for 30 minutes of moderate exercise most days of the week.',
    '😴 Get 7–8 hours of quality sleep every night — it supports your immune system.',
    '🥦 Fill half your plate with vegetables and fruit at every meal.',
    '🧘 Practice 5 minutes of deep breathing daily to reduce stress and lower BP.',
    '🚭 Avoid smoking and limit alcohol — both increase risk of multiple chronic diseases.',
    '📋 Keep all medical appointments and don\'t skip scheduled tests.',
    '💊 Take medications at the same time each day to improve adherence.',
    '📝 Keep a health journal — noting symptoms helps your care team tailor treatment.',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kRadiusLg),
        boxShadow: kCardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(kRadiusLg),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(kRadiusMd),
                    ),
                    child: const Center(
                        child: Text('🌟', style: TextStyle(fontSize: 22))),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('General Wellness Guide',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kText)),
                        SizedBox(height: 2),
                        Text('Healthy habits for everyone',
                            style: TextStyle(
                                fontSize: 11, color: kSubtext)),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kSubtext,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: kBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: _tips
                    .map((tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(tip,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: kSubtext,
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
