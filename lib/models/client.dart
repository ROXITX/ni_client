import 'dart:math';

class Client {
  int id;
  String firstName;
  String lastName;
  String dob;
  String gender;
  String email;
  String phone;
  String occupation;
  String description;
  /// Each program map structure (fields):
  /// programType (String)
  /// count / startDate / frequency / timeSlot / dayOfWeek / dateOfMonth / duration
  /// createdAt / updatedAt (ISO8601 String) + version (int) + active (bool)
  List<Map<String, dynamic>> programs; // multi-program support
  
  Client({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.dob,
    required this.gender,
    required this.email,
    required this.phone,
    required this.occupation,
    required this.description,
    List<Map<String, dynamic>>? programs,
  }) : programs = programs ?? [];

  // Backward compatibility getter for existing code
  Map<String, dynamic>? get scheduleInfo => programs.isNotEmpty ? programs.first : null;
  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'dob': dob,
        'gender': gender,
        'email': email,
        'phone': phone,
        'occupation': occupation,
        'description': description,
        'programs': programs,
        // Backward compatibility (kept for old reads)
        'scheduleInfo': scheduleInfo,
      };

  // ADD THIS FACTORY CONSTRUCTOR
  factory Client.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> programsList = [];
    
    // Handle backward compatibility - if old scheduleInfo exists, convert it to programs list
    if (json['programs'] != null) {
      programsList = List<Map<String, dynamic>>.from(json['programs']);
    } else if (json['scheduleInfo'] != null) {
      // Migrate legacy single program to new structure with metadata
      final legacy = Map<String, dynamic>.from(json['scheduleInfo']);
      final nowIso = DateTime.now().toUtc().toIso8601String();
      if (!legacy.containsKey('createdAt')) legacy['createdAt'] = nowIso;
      if (!legacy.containsKey('updatedAt')) legacy['updatedAt'] = nowIso;
      legacy['version'] = 1;
      legacy['active'] = true;
      programsList = [legacy];
    }
    // Ensure metadata exists for each program
    final nowIso = DateTime.now().toUtc().toIso8601String();
    for (final p in programsList) {
      p['createdAt'] ??= nowIso;
      p['updatedAt'] ??= nowIso;
      p['version'] ??= 1;
      p['active'] ??= true;
      // Auto-assign unique ID for program separation verification
      p['programEnrollmentId'] ??= '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    }
    
    return Client(
      id: json['id'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      dob: json['dob'],
      gender: json['gender'],
      email: json['email'],
      phone: json['phone'],
      occupation: json['occupation'],
      description: json['description'],
      programs: programsList,
    );
  }

  // Methods to handle multiple programs
  void addProgram(Map<String, dynamic> programInfo) {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    programInfo['createdAt'] ??= nowIso;
    programInfo['updatedAt'] = nowIso;
    programInfo['version'] = (programInfo['version'] ?? 1);
    programInfo['active'] ??= true;
    // Ensure ID
    programInfo['programEnrollmentId'] ??= '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    programs.add(programInfo);
  }

  void updateProgram(int index, Map<String, dynamic> programInfo) {
    if (index >= 0 && index < programs.length) {
      final existing = programs[index];
      final nowIso = DateTime.now().toUtc().toIso8601String();
      // Preserve createdAt, increment version
      programInfo['createdAt'] = existing['createdAt'] ?? nowIso;
      programInfo['updatedAt'] = nowIso;
      programInfo['version'] = (existing['version'] ?? 1) + 1;
      programInfo['active'] = existing['active'] ?? true;
      programs[index] = programInfo;
    }
  }

  void removeProgram(int index) {
    if (index >= 0 && index < programs.length) {
      programs.removeAt(index);
    }
  }

  Map<String, dynamic>? getProgramByType(String programType) {
    return programs.firstWhere(
      (program) => program['programType'] == programType,
      orElse: () => {},
    ).isEmpty ? null : programs.firstWhere(
      (program) => program['programType'] == programType,
      orElse: () => {},
    );
  }

  int? getProgramIndex(String programType) {
    final idx = programs.indexWhere((p) => p['programType'] == programType);
    return idx < 0 ? null : idx;
  }

  Client copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? dob,
    String? gender,
    String? email,
    String? phone,
    String? occupation,
    String? description,
    List<Map<String, dynamic>>? programs,
  }) {
    return Client(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      occupation: occupation ?? this.occupation,
      description: description ?? this.description,
      programs: programs ?? this.programs,
    );
  }

  Map<String, dynamic> programDescriptor(int index) {
    final p = programs[index];
    return {
      'programType': p['programType'],
      'count': p['count'],
      'active': p['active'],
      'version': p['version'],
      'createdAt': p['createdAt'],
      'updatedAt': p['updatedAt'],
    };
  }

  factory Client.empty() {
    return Client(
      id: 0,
      firstName: '',
      lastName: '',
      dob: '',
      gender: '',
      email: '',
      phone: '',
      occupation: '',
      description: '',
      programs: [],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Client && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
