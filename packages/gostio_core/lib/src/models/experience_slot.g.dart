// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'experience_slot.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExperienceSlot _$ExperienceSlotFromJson(Map<String, dynamic> json) =>
    ExperienceSlot(
      id: (json['id'] as num).toInt(),
      experienceId: (json['experienceId'] as num).toInt(),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      capacity: (json['capacity'] as num).toInt(),
      remainingCapacity: (json['remainingCapacity'] as num).toInt(),
      isActive: json['isActive'] as bool,
    );
