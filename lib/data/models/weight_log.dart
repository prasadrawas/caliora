import 'package:cloud_firestore/cloud_firestore.dart';

class WeightLog {
  final String id;
  final double weight;
  final String date;
  final DateTime timestamp;

  WeightLog({
    required this.id,
    required this.weight,
    required this.date,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory WeightLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeightLog(
      id: doc.id,
      weight: (data['weight'] ?? 0).toDouble(),
      date: data['date'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'weight': weight,
      'date': date,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
