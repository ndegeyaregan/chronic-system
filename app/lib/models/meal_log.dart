class MealLog {
  final String id;
  final String mealType;
  final String description;
  final int? calories;
  final DateTime loggedAt;
  final List<String> foods;
  final int waterCups;
  final String? photoUrl;

  const MealLog({
    required this.id,
    required this.mealType,
    required this.description,
    this.calories,
    required this.loggedAt,
    this.foods = const [],
    this.waterCups = 0,
    this.photoUrl,
  });

  factory MealLog.fromJson(Map<String, dynamic> json) => MealLog(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        mealType:
            (json['meal_type'] ?? json['mealType'] ?? 'snack').toString(),
        description: (json['description'] ?? '').toString(),
        calories: json['calories'] != null
            ? (json['calories'] as num).toInt()
            : null,
        loggedAt: DateTime.parse(
            (json['logged_at'] ?? json['loggedAt'] ?? DateTime.now().toIso8601String())
                .toString()),
        foods: List<String>.from(
            (json['foods'] as List?)?.map((e) => e.toString()) ?? []),
        waterCups: ((json['water_cups'] ?? json['waterCups'] ?? 0) as num)
            .toInt(),
        photoUrl: (json['photo_url'] ?? json['photoUrl']) as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'meal_type': mealType,
        'description': description,
        'calories': calories,
        'logged_at': loggedAt.toIso8601String(),
        'foods': foods,
        'water_cups': waterCups,
        'photo_url': photoUrl,
      };

  String get mealTypeLabel {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return 'Snack';
    }
  }

  String get mealTypeEmoji {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return '🌅';
      case 'lunch':
        return '☀️';
      case 'dinner':
        return '🌙';
      default:
        return '🍎';
    }
  }
}
