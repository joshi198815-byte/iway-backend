class TrackingTimelineItem {
  final String kind;
  final String type;
  final DateTime at;
  final Map<String, dynamic> payload;

  TrackingTimelineItem({
    required this.kind,
    required this.type,
    required this.at,
    required this.payload,
  });

  factory TrackingTimelineItem.fromBackendJson(Map<String, dynamic> json) {
    return TrackingTimelineItem(
      kind: (json['kind'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      at: DateTime.tryParse((json['at'] ?? '').toString()) ?? DateTime.now(),
      payload: (json['payload'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value),
          ) ??
          <String, dynamic>{},
    );
  }
}
