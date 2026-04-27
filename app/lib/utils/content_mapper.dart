import '../services/cms_service.dart';

/// Maps CMS content to the ConditionInfo model used by the education screen
class ContentMapper {
  /// Map emoji for common conditions
  static final Map<String, String> _conditionEmojis = {
    'hypertension': '🩺',
    'high blood pressure': '🩺',
    'diabetes': '🩸',
    'heart': '❤️',
    'heart disease': '❤️',
    'coronary': '❤️',
    'copd': '💨',
    'asthma': '💨',
    'lung': '💨',
    'kidney': '🫘',
    'renal': '🫘',
    'ckd': '🫘',
  };

  /// Parse CMS content and extract sections from body
  /// Expected format in body (one of):
  /// 1. Structured JSON or key-value format
  /// 2. Markdown sections with headers
  /// 3. Bullet-point lists separated by section headers
  static List<String> _extractSection(String? body, String sectionName) {
    if (body == null || body.isEmpty) return [];

    final items = <String>[];
    final lowerBody = body.toLowerCase();
    
    // Common section headers and their variations
    final headerPatterns = {
      'what': [r'\bwhat\s+(?:is\s+)?it\b', r'\bdefinition\b', r'\boverview\b'],
      'warnings': [r'\bwarning\s+signs\b', r'\bsymptoms\b', r'\bsigns\b'],
      'diet': [r'\bdiet\s+tips\b', r'\bnutrition\b', r'\bfood\b'],
      'lifestyle': [r'\blifestyle\s+tips\b', r'\bactivity\b', r'\bexercise\b'],
      'medication': [r'\bmedication\s+tips\b', r'\bmedicine\b', r'\bdrugs\b'],
      'seek': [r'\bwhen\s+to\s+seek\s+help\b', r'\bemergency\b', r'\bcritical\b'],
    };

    final patterns = headerPatterns[sectionName] ?? [];
    
    // Try to find the section and extract its content
    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(body);
      
      if (match != null) {
        // Extract content after the header until the next header or end
        final startIdx = match.end;
        int endIdx = body.length;

        // Find the next section header
        for (final headerSet in headerPatterns.values) {
          for (final headerPattern in headerSet) {
            final nextMatch = RegExp(headerPattern, caseSensitive: false)
                .firstMatch(body.substring(startIdx));
            if (nextMatch != null && nextMatch.start < endIdx - startIdx) {
              endIdx = startIdx + nextMatch.start;
            }
          }
        }

        final sectionContent = body.substring(startIdx, endIdx).trim();
        
        // Parse bullet points or lines
        final lines = sectionContent.split('\n');
        for (final line in lines) {
          final trimmed = line
              .replaceAll(RegExp(r'^[-•*]\s*'), '') // Remove bullet points
              .replaceAll(RegExp(r'^\d+\.\s*'), '')  // Remove numbered lists
              .trim();
          if (trimmed.isNotEmpty && trimmed.length > 3) {
            items.add(trimmed);
          }
        }

        if (items.isNotEmpty) break;
      }
    }

    return items.take(6).toList(); // Limit to 6 items
  }

  /// Convert CMS content to ConditionInfo-compatible data
  static ConditionInfoData fromCMSContent(CMSContent content) {
    final title = content.title;
    final body = content.body ?? '';

    // Get emoji based on condition name
    String emoji = '📚';
    for (final entry in _conditionEmojis.entries) {
      if (title.toLowerCase().contains(entry.key)) {
        emoji = entry.value;
        break;
      }
    }

    // Extract sections from body
    final whatIsItList = _extractSection(body, 'what');
    final whatIsIt = whatIsItList.isNotEmpty
        ? whatIsItList.join(' ')
        : _fallbackWhatIsIt(title);
    
    final warningSigns = _extractSection(body, 'warnings');
    final dietTips = _extractSection(body, 'diet');
    final lifestyleTips = _extractSection(body, 'lifestyle');
    final medicationTips = _extractSection(body, 'medication');
    
    final seekHelpList = _extractSection(body, 'seek');
    final whenToSeekHelp = seekHelpList.isNotEmpty
        ? seekHelpList.join(' ')
        : _fallbackWhenToSeekHelp(title);

    return ConditionInfoData(
      title: title,
      emoji: emoji,
      whatIsIt: whatIsIt,
      warningSigns: warningSigns.isEmpty ? ['Please consult a healthcare provider for detailed information'] : warningSigns,
      dietTips: dietTips.isEmpty ? ['Consult a dietitian for personalized advice'] : dietTips,
      lifestyleTips: lifestyleTips.isEmpty ? ['Consult your healthcare provider'] : lifestyleTips,
      medicationTips: medicationTips.isEmpty ? ['Take medications as prescribed by your doctor'] : medicationTips,
      whenToSeekHelp: whenToSeekHelp,
    );
  }

  static String _fallbackWhatIsIt(String conditionName) {
    return 'For detailed information about $conditionName, please consult your healthcare provider.';
  }

  static String _fallbackWhenToSeekHelp(String conditionName) {
    return 'If you experience concerning symptoms related to $conditionName, contact your healthcare provider or call emergency services.';
  }
}

/// Data class that mirrors ConditionInfo structure for easier mapping
class ConditionInfoData {
  final String title;
  final String emoji;
  final String whatIsIt;
  final List<String> warningSigns;
  final List<String> dietTips;
  final List<String> lifestyleTips;
  final List<String> medicationTips;
  final String whenToSeekHelp;

  ConditionInfoData({
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
