class Review {
  final double rating;
  final String comment;
  final int timestamp; // Store as millisecondsSinceEpoch

  Review({
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  // Factory constructor to create a Review from a Map (Firebase data)
  factory Review.fromJson(Map<dynamic, dynamic> json) {
    return Review(
      rating: (json['rating'] as num?)?.toDouble() ??
          0.0, // Handle null/incorrect types
      comment: json['comment'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  // Method to convert a Review object to a Map for saving to Firebase
  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp,
    };
  }
}
