class ResourceMaterial {
  final String id;
  final String filename;
  final String contentType;
  final int sizeBytes;
  final String category;
  final List<String> tags;
  final String questionId;
  final DateTime uploadedAt;
  final String sha256;

  ResourceMaterial({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.sizeBytes,
    required this.category,
    required this.tags,
    required this.questionId,
    required this.uploadedAt,
    required this.sha256,
  });

  factory ResourceMaterial.fromJson(Map<String, dynamic> json) {
    return ResourceMaterial(
      id: json['id'] ?? '',
      filename: json['filename'] ?? '',
      contentType: json['content_type'] ?? '',
      sizeBytes: json['size_bytes'] ?? 0,
      category: json['category'] ?? '',
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      questionId: json['question_id'] ?? '',
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.tryParse(json['uploaded_at']) ?? DateTime.now()
          : DateTime.now(),
      sha256: json['sha256'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'content_type': contentType,
      'size_bytes': sizeBytes,
      'category': category,
      'tags': tags,
      'question_id': questionId,
      'uploaded_at': uploadedAt.toIso8601String(),
      'sha256': sha256,
    };
  }
}
