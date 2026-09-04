import 'package:json_annotation/json_annotation.dart';

part 'experience_slot.g.dart';

// The remaining places are the server's own count over the reservations
// against the term, so nothing here recounts them.
@JsonSerializable(createToJson: false)
class ExperienceSlot {
  const ExperienceSlot({
    required this.id,
    required this.experienceId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.capacity,
    required this.remainingCapacity,
    required this.isActive,
  });

  factory ExperienceSlot.fromJson(Map<String, dynamic> json) =>
      _$ExperienceSlotFromJson(json);

  final int id;
  final int experienceId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final int capacity;
  final int remainingCapacity;
  final bool isActive;

  int get bookedCapacity => capacity - remainingCapacity;

  bool get isBooked => bookedCapacity > 0;
}
