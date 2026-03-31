/// Emotion experienced after an Incienso session.
enum InciensoEmotion {
  /// Relaxed / Sleepy.
  relaxed,

  /// Peaceful / At ease.
  peaceful,

  /// Deep meditative state.
  deep,

  /// Energized / Alert.
  energized,

  /// Transformative experience.
  transformed;

  /// Emoji representation for UI display.
  String get emoji => switch (this) {
    relaxed     => '\u{1F634}', // sleeping face
    peaceful    => '\u{1F60C}', // relieved face
    deep        => '\u{1F9D8}', // person in lotus position
    energized   => '\u{26A1}',  // high voltage
    transformed => '\u{1F300}', // cyclone
  };
}

/// Perceived intensity of an Incienso session.
enum InciensoIntensity {
  /// Gentle / Soft.
  gentle,

  /// Moderate.
  moderate,

  /// Intense.
  intense,
}

/// Post-session review data for an Incienso practice.
///
/// Captures the user's subjective experience after a Camara Neom session.
/// Feeds into rankings, recommendations, and social proof.
class InciensoReview {
  /// Session this review belongs to.
  final String sessionId;

  /// Incienso preset that was practiced.
  final String? inciensoId;

  /// Author of the review.
  final String? userId;

  /// When the review was submitted.
  final DateTime timestamp;

  /// Overall emotional experience (required).
  final InciensoEmotion emotion;

  /// Perceived intensity level (required).
  final InciensoIntensity intensity;

  /// Whether the user would recommend this Incienso (required).
  final bool recommended;

  /// Selected context tags (optional).
  final List<String> tags;

  /// Free-text note, max 200 chars (optional).
  final String? note;

  const InciensoReview({
    required this.sessionId,
    this.inciensoId,
    this.userId,
    required this.timestamp,
    required this.emotion,
    required this.intensity,
    required this.recommended,
    this.tags = const [],
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    if (inciensoId != null) 'inciensoId': inciensoId,
    if (userId != null) 'userId': userId,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'emotion': emotion.name,
    'intensity': intensity.name,
    'recommended': recommended,
    'tags': tags,
    if (note != null) 'note': note,
  };

  factory InciensoReview.fromJson(Map<String, dynamic> json) => InciensoReview(
    sessionId: json['sessionId'] as String? ?? '',
    inciensoId: json['inciensoId'] as String?,
    userId: json['userId'] as String?,
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      json['timestamp'] as int? ?? 0,
    ),
    emotion: InciensoEmotion.values.firstWhere(
      (e) => e.name == json['emotion'],
      orElse: () => InciensoEmotion.peaceful,
    ),
    intensity: InciensoIntensity.values.firstWhere(
      (i) => i.name == json['intensity'],
      orElse: () => InciensoIntensity.moderate,
    ),
    recommended: json['recommended'] as bool? ?? true,
    tags: (json['tags'] as List?)?.cast<String>() ?? [],
    note: json['note'] as String?,
  );

  @override
  String toString() =>
      'InciensoReview(session=$sessionId, emotion=${emotion.name}, '
      'intensity=${intensity.name}, recommended=$recommended, '
      'tags=${tags.length}, note=${note != null ? "yes" : "no"})';
}
