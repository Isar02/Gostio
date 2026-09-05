// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stay_calendar_day.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StayCalendarDay _$StayCalendarDayFromJson(Map<String, dynamic> json) =>
    StayCalendarDay(
      date: DateTime.parse(json['date'] as String),
      isBookable: json['isBookable'] as bool,
      price: (json['price'] as num).toDouble(),
    );
