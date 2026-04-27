enum PartnerType { gym, nutritionist, counsellor }

class LifestylePartner {
  final String id;
  final String name;
  final PartnerType type;
  final String city;
  final String province;
  final String? phone;
  final String? website;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String logoColor;

  const LifestylePartner({
    required this.id,
    required this.name,
    required this.type,
    required this.city,
    required this.province,
    this.phone,
    this.website,
    this.latitude,
    this.longitude,
    this.address,
    this.logoColor = '#003DA5',
  });

  factory LifestylePartner.fromJson(Map<String, dynamic> json) =>
      LifestylePartner(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        type: _parseType((json['type'] ?? 'gym').toString()),
        city: (json['city'] ?? '').toString(),
        province: (json['province'] ?? '').toString(),
        phone: json['phone'] as String?,
        website: json['website'] as String?,
        latitude: json['latitude'] != null
            ? double.tryParse(json['latitude'].toString())
            : null,
        longitude: json['longitude'] != null
            ? double.tryParse(json['longitude'].toString())
            : null,
        address: json['address'] as String?,
        logoColor: (json['logo_color'] as String?) ?? '#003DA5',
      );

  static PartnerType _parseType(String s) {
    switch (s.toLowerCase()) {
      case 'nutritionist':
        return PartnerType.nutritionist;
      case 'counsellor':
      case 'counselor':
        return PartnerType.counsellor;
      default:
        return PartnerType.gym;
    }
  }

  String get typeLabel {
    switch (type) {
      case PartnerType.gym:         return 'Gym';
      case PartnerType.nutritionist: return 'Nutritionist';
      case PartnerType.counsellor:  return 'Counsellor';
    }
  }
}

class PartnerVideo {
  final String id;
  final String partnerId;
  final String title;
  final String youtubeVideoId;
  final String durationLabel;
  final String difficulty;
  final String category;

  const PartnerVideo({
    required this.id,
    required this.partnerId,
    required this.title,
    required this.youtubeVideoId,
    required this.durationLabel,
    required this.difficulty,
    required this.category,
  });

  factory PartnerVideo.fromJson(Map<String, dynamic> json) => PartnerVideo(
        id:             (json['id'] ?? '').toString(),
        partnerId:      (json['partner_id'] ?? '').toString(),
        title:          (json['title'] ?? '').toString(),
        youtubeVideoId: (json['youtube_video_id'] ?? '').toString(),
        durationLabel:  (json['duration_label'] ?? '30 min').toString(),
        difficulty:     (json['difficulty'] ?? 'Beginner').toString(),
        category:       (json['category'] ?? 'Strength').toString(),
      );

  /// Extract video ID from YouTube URL or return as-is if already an ID
  String getVideoId() {
    if (youtubeVideoId.isEmpty) return '';
    
    // If it's already just an ID (11 chars, alphanumeric, dash, underscore)
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(youtubeVideoId)) {
      return youtubeVideoId;
    }

    // Format: https://www.youtube.com/watch?v=dQw4w9WgXcQ
    if (youtubeVideoId.contains('watch?v=')) {
      return youtubeVideoId.split('watch?v=')[1].split('&')[0];
    }

    // Format: https://youtu.be/dQw4w9WgXcQ
    if (youtubeVideoId.contains('youtu.be/')) {
      return youtubeVideoId.split('youtu.be/')[1].split('?')[0];
    }

    // Return original if we can't extract
    return youtubeVideoId;
  }

  Map<String, String> toWorkoutMap(String channelName) => {
        'videoId':    getVideoId(),
        'title':      title,
        'channel':    channelName,
        'duration':   durationLabel,
        'difficulty': difficulty,
        'category':   category,
      };
}
