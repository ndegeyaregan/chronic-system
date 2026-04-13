import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/lifestyle_provider.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_input.dart';

class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key});

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  String _mealType = 'breakfast';
  final _descCtrl = TextEditingController();
  final _caloriesCtrl = TextEditingController();
  final _foodsCtrl = TextEditingController();

  XFile? _photoFile;

  // Snack list support (up to 3 snack entries when meal type is snack)
  final List<_SnackEntry> _snacks = [_SnackEntry()];

  final _mealTypes = [
    {'key': 'breakfast', 'label': 'Breakfast', 'emoji': '🌅'},
    {'key': 'lunch', 'label': 'Lunch', 'emoji': '☀️'},
    {'key': 'dinner', 'label': 'Dinner', 'emoji': '🌙'},
    {'key': 'snack', 'label': 'Snack', 'emoji': '🍎'},
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    _caloriesCtrl.dispose();
    _foodsCtrl.dispose();
    for (final s in _snacks) {
      s.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await _showPhotoSourceDialog();
    if (source == null) return;
    final picked = await picker.pickImage(source: source, imageQuality: 70);
    if (picked != null && mounted) {
      setState(() => _photoFile = picked);
    }
  }

  Future<ImageSource?> _showPhotoSourceDialog() {
    return showDialog<ImageSource>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getAdvice(List<String> conditions) {
    final advice = <Map<String, dynamic>>[];
    final foodsLower = _foodsCtrl.text.toLowerCase();
    final calories = int.tryParse(_caloriesCtrl.text) ?? 0;

    // General calorie warning
    if (calories > 800) {
      advice.add({
        'text': '🔴 High calorie meal. Consider splitting into smaller portions.',
        'color': kError,
      });
    }

    // General positive
    if (_containsAny(foodsLower, ['water', 'vegetable', 'vegetables', 'fruit', 'fruits', 'salad'])) {
      advice.add({
        'text': '✅ Good hydration and nutrients!',
        'color': kSuccess,
      });
    }

    for (final condition in conditions) {
      final c = condition.toLowerCase();

      if (c.contains('diabetes')) {
        if (_containsAny(foodsLower, ['white rice', 'sugar', 'candy', 'cake', 'juice', 'soda', 'potato', 'bread', 'pasta', 'banana'])) {
          advice.add({
            'text': '⚠️ High glycaemic foods detected. Consider smaller portions or low-GI alternatives.',
            'color': kWarning,
          });
        }
        if (_containsAny(foodsLower, ['vegetables', 'salad', 'beans', 'oats', 'nuts'])) {
          advice.add({
            'text': '✅ Great choice! Low-GI foods help manage blood sugar.',
            'color': kSuccess,
          });
        }
      }

      if (c.contains('hypertension')) {
        if (_containsAny(foodsLower, ['salt', 'chips', 'processed', 'bacon', 'sausage', 'fast food'])) {
          advice.add({
            'text': '⚠️ High-sodium foods can raise blood pressure. Limit salt intake.',
            'color': kWarning,
          });
        }
        if (_containsAny(foodsLower, ['banana', 'spinach', 'avocado'])) {
          advice.add({
            'text': '✅ Potassium-rich foods help lower blood pressure.',
            'color': kSuccess,
          });
        }
      }

      if (c.contains('heart') || c.contains('copd')) {
        if (_containsAny(foodsLower, ['fried', 'butter', 'cream', 'cheese', 'bacon'])) {
          advice.add({
            'text': '⚠️ Saturated fats may impact heart health. Choose lean proteins.',
            'color': kWarning,
          });
        }
      }
    }

    // Deduplicate by text
    final seen = <String>{};
    return advice.where((a) => seen.add(a['text'] as String)).toList();
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  Future<void> _submit() async {
    if (_mealType == 'snack') {
      // Log each snack separately
      final validSnacks = _snacks
          .where((s) => s.descCtrl.text.trim().isNotEmpty)
          .toList();
      if (validSnacks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please describe at least one snack.'),
            backgroundColor: kWarning,
          ),
        );
        return;
      }
      bool allSuccess = true;
      for (final snack in validSnacks) {
        final foods = snack.foodsCtrl.text
            .trim()
            .split(',')
            .map((f) => f.trim())
            .where((f) => f.isNotEmpty)
            .toList();
        final success = await ref.read(lifestyleProvider.notifier).logMeal({
          'meal_type': 'snack',
          'description': snack.descCtrl.text.trim(),
          if (snack.caloriesCtrl.text.isNotEmpty)
            'calories': int.tryParse(snack.caloriesCtrl.text),
          'foods': foods,
        });
        if (!success) allSuccess = false;
      }
      if (allSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Snack(s) logged successfully!'),
            backgroundColor: kSuccess,
          ),
        );
        context.pop();
      }
      return;
    }

    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe what you ate.'),
          backgroundColor: kWarning,
        ),
      );
      return;
    }

    final foods = _foodsCtrl.text
        .trim()
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList();

    final success = await ref.read(lifestyleProvider.notifier).logMeal({
      'meal_type': _mealType,
      'description': _descCtrl.text.trim(),
      if (_caloriesCtrl.text.isNotEmpty)
        'calories': int.tryParse(_caloriesCtrl.text),
      'foods': foods,
    });

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal logged successfully!'),
          backgroundColor: kSuccess,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lifestyleProvider);
    final conditions = ref.watch(authProvider).member?.conditions ?? [];
    final advice = _getAdvice(conditions);

    return Scaffold(
      appBar: AppBar(title: const Text('Log Meal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Meal Type',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kText),
            ),
            const SizedBox(height: 10),
            Row(
              children: _mealTypes
                  .map(
                    (t) => Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _mealType = t['key']!),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _mealType == t['key'] ? kPrimary : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _mealType == t['key'] ? kPrimary : kBorder,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(t['emoji']!, style: const TextStyle(fontSize: 20)),
                              const SizedBox(height: 4),
                              Text(
                                t['label']!,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: _mealType == t['key'] ? Colors.white : kText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            // Meal photo picker
            GestureDetector(
              onTap: _pickPhoto,
              child: _photoFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: kIsWeb
                          ? Image.network(
                              _photoFile!.path,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_photoFile!.path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: kPrimary.withValues(alpha: 0.15)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('📸', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Text(
                            'Add Photo (optional)',
                            style:
                                TextStyle(fontSize: 13, color: kSubtext),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            if (_mealType == 'snack') ...[
              ..._snacks.asMap().entries.map((entry) {
                final i = entry.key;
                final snack = entry.value;
                return _SnackCard(
                  index: i,
                  entry: snack,
                  canRemove: _snacks.length > 1,
                  onRemove: () =>
                      setState(() => _snacks.removeAt(i)),
                  onChanged: () => setState(() {}),
                );
              }),
              if (_snacks.length < 3)
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _snacks.add(_SnackEntry())),
                  icon: const Icon(Icons.add),
                  label: const Text('+ Add Another Snack'),
                  style: TextButton.styleFrom(
                      foregroundColor: kPrimary),
                ),
            ] else ...[
              AppInput(
                label: 'Description',
                hint: 'e.g. Oats with banana and low-fat milk',
                controller: _descCtrl,
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Foods (comma-separated, optional)',
                hint: 'e.g. Oats, Banana, Milk',
                controller: _foodsCtrl,
                textInputAction: TextInputAction.next,
                onChanged: (_) => setState(() {}),
              ),
              // Nutrition advice banner
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: advice.isNotEmpty
                    ? Padding(
                        key: ValueKey(advice.map((a) => a['text']).join()),
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          children: advice.map((a) {
                            final color = a['color'] as Color;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: color.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    color == kSuccess
                                        ? Icons.check_circle_outline
                                        : color == kError
                                            ? Icons.error_outline
                                            : Icons.info_outline,
                                    color: color,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      a['text'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
              const SizedBox(height: 16),
              AppInput(
                label: 'Calories (optional)',
                hint: 'e.g. 350',
                controller: _caloriesCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 12),
              Text(
                state.error!,
                style: const TextStyle(color: kError, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 28),
            AppButton(
              label: 'Log Meal',
              onPressed: _submit,
              isLoading: state.isLoading,
              leadingIcon: Icons.restaurant_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _SnackEntry {
  final descCtrl = TextEditingController();
  final foodsCtrl = TextEditingController();
  final caloriesCtrl = TextEditingController();

  void dispose() {
    descCtrl.dispose();
    foodsCtrl.dispose();
    caloriesCtrl.dispose();
  }
}

class _SnackCard extends StatelessWidget {
  final int index;
  final _SnackEntry entry;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _SnackCard({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🍎', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Snack ${index + 1}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kText),
              ),
              const Spacer(),
              if (canRemove)
                GestureDetector(
                  onTap: onRemove,
                  child: const Icon(Icons.close, size: 18, color: kSubtext),
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppInput(
            label: 'Description',
            hint: 'e.g. Apple and nuts',
            controller: entry.descCtrl,
            maxLines: 1,
            textInputAction: TextInputAction.next,
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 10),
          AppInput(
            label: 'Foods (optional)',
            hint: 'e.g. Apple, Almonds',
            controller: entry.foodsCtrl,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          AppInput(
            label: 'Calories (optional)',
            hint: 'e.g. 120',
            controller: entry.caloriesCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }
}
