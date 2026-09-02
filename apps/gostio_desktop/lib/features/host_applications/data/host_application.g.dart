// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'host_application.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HostApplication _$HostApplicationFromJson(Map<String, dynamic> json) =>
    HostApplication(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      username: json['username'] as String,
      applicantName: json['applicantName'] as String,
      status: json['status'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      reviewedByUserId: (json['reviewedByUserId'] as num?)?.toInt(),
      reviewedByName: json['reviewedByName'] as String?,
      reviewedAt: json['reviewedAt'] == null
          ? null
          : DateTime.parse(json['reviewedAt'] as String),
      decisionReason: json['decisionReason'] as String?,
    );
