import 'package:cloud_firestore/cloud_firestore.dart';

/// A user-saved occasion (e.g. Birthday, Anniversary) stored under users/{uid}/occasions.
class UserOccasionModel {
  const UserOccasionModel({
    required this.id,
    required this.name,
    required this.date,
  });

  final String id;
  final String name;
  final DateTime date;

  static UserOccasionModel? fromFirestore(String id, Map<String, dynamic>? data) {
    if (data == null) return null;
    final name = data['name']?.toString().trim() ?? '';
    if (name.isEmpty) return null;
    final date = data['date'];
    DateTime? dateTime;
    if (date is Timestamp) {
      dateTime = date.toDate();
    } else if (date is DateTime) {
      dateTime = date;
    }
    if (dateTime == null) return null;
    return UserOccasionModel(id: id, name: name, date: dateTime);
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'date': Timestamp.fromDate(date),
      };
}
