class Course {
  int id;
  String name;
  String description;
  String? duration; // Default duration hint e.g. "1 Hour"

  Course({
    required this.id,
    required this.name,
    required this.description,
    this.duration,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'duration': duration,
    };
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      duration: json['duration'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Course && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
