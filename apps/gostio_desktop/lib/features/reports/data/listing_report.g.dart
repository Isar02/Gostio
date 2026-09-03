// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'listing_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ListingReportRow _$ListingReportRowFromJson(Map<String, dynamic> json) =>
    ListingReportRow(
      cityId: (json['cityId'] as num).toInt(),
      city: json['city'] as String,
      categoryId: (json['categoryId'] as num).toInt(),
      category: json['category'] as String,
      listingsPublished: (json['listingsPublished'] as num).toInt(),
      bookings: (json['bookings'] as num).toInt(),
      unitsSold: (json['unitsSold'] as num).toInt(),
      grossCharged: (json['grossCharged'] as num).toDouble(),
      reviewCount: (json['reviewCount'] as num).toInt(),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
    );

ListingReportTotals _$ListingReportTotalsFromJson(Map<String, dynamic> json) =>
    ListingReportTotals(
      listingsPublished: (json['listingsPublished'] as num).toInt(),
      bookings: (json['bookings'] as num).toInt(),
      unitsSold: (json['unitsSold'] as num).toInt(),
      grossCharged: (json['grossCharged'] as num).toDouble(),
      reviewCount: (json['reviewCount'] as num).toInt(),
      averageRating: (json['averageRating'] as num?)?.toDouble(),
    );
