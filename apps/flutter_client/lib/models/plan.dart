class PlanItem {
  final String id;
  final String planType;
  final String title;
  final String content;
  final String targetDate;
  final String status;
  final int priority;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  PlanItem({
    required this.id,
    required this.planType,
    required this.title,
    required this.content,
    required this.targetDate,
    required this.status,
    required this.priority,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlanItem.fromJson(Map<String, dynamic> json) {
    return PlanItem(
      id: json['id']?.toString() ?? '',
      planType: json['plan_type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      targetDate: json['target_date']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      priority: (json['priority'] as num?)?.toInt() ?? 1,
      source: json['source']?.toString() ?? 'manual',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
