enum ProgramType {
  gbp,
  payanam,
  ninertia,
  becoming,
  happyHuddle,
  oneToOneLifeCoaching,
}

enum SessionDuration {
  halfHour, // 0.5 hours
  oneHour, // 1 hour
  twoHours, // 2 hours
  threeHours, // 3 hours
  wholeDay, // Whole day
}

extension ProgramTypeExtension on ProgramType {
  String get displayName {
    switch (this) {
      case ProgramType.gbp:
        return 'GBP';
      case ProgramType.payanam:
        return 'Payanam';
      case ProgramType.ninertia:
        return 'Ninertia';
      case ProgramType.becoming:
        return 'Becoming';
      case ProgramType.happyHuddle:
        return 'Happy Huddle';
      case ProgramType.oneToOneLifeCoaching:
        return '1:1 Life Coaching';
    }
  }

  static ProgramType fromString(String value) {
    switch (value) {
      case 'gbp':
        return ProgramType.gbp;
      case 'payanam':
        return ProgramType.payanam;
      case 'ninertia':
        return ProgramType.ninertia;
      case 'becoming':
        return ProgramType.becoming;
      case 'happyHuddle':
        return ProgramType.happyHuddle;
      case 'oneToOneLifeCoaching':
        return ProgramType.oneToOneLifeCoaching;
      default:
        return ProgramType.gbp; // Default fallback
    }
  }
}

extension SessionDurationExtension on SessionDuration {
  String get displayName {
    switch (this) {
      case SessionDuration.halfHour:
        return '0.5 Hour';
      case SessionDuration.oneHour:
        return '1 Hour';
      case SessionDuration.twoHours:
        return '2 Hours';
      case SessionDuration.threeHours:
        return '3 Hours';
      case SessionDuration.wholeDay:
        return 'Whole Day';
    }
  }

  double get hours {
    switch (this) {
      case SessionDuration.halfHour:
        return 0.5;
      case SessionDuration.oneHour:
        return 1.0;
      case SessionDuration.twoHours:
        return 2.0;
      case SessionDuration.threeHours:
        return 3.0;
      case SessionDuration.wholeDay:
        return 8.0; // 10 AM to 6 PM
    }
  }

  static SessionDuration fromString(String value) {
    switch (value) {
      case 'halfHour':
        return SessionDuration.halfHour;
      case 'oneHour':
        return SessionDuration.oneHour;
      case 'twoHours':
        return SessionDuration.twoHours;
      case 'threeHours':
        return SessionDuration.threeHours;
      case 'wholeDay':
        return SessionDuration.wholeDay;
      default:
        return SessionDuration.oneHour; // Default fallback
    }
  }
}

class Session {
  bool notifiedTwoHour = false;
  bool notifiedFiveMin = false;
  bool read;
  int id;
  int clientId;
  String status;
  int sessionNo;
  String time;
  String date;
  int? rating;
  String? comments;
  ProgramType? programType;
  String? courseName; // Added for dynamic course support
  SessionDuration? duration;
  String? programEnrollmentId; // Added to link session to specific program enrollment
  String? firestoreDocId; // Internal Firestore Document ID
  
  Session({
    required this.id,
    required this.clientId,
    required this.status,
    required this.sessionNo,
    required this.time,
    required this.date,
    this.rating,
    this.comments,
    this.read = false,
    this.notifiedTwoHour = false,
    this.notifiedFiveMin = false,
    this.programType,
    this.courseName,
    this.duration,
    this.programEnrollmentId,
    this.firestoreDocId,
  });
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'status': status,
      'sessionNo': sessionNo,
      'time': time,
      'date': date,
      'rating': rating,
      'comments': comments,
      'read': read,
      'notifiedTwoHour': notifiedTwoHour,
      'notifiedFiveMin': notifiedFiveMin,
      'programType': programType?.name,
      'courseName': courseName,
      'duration': duration?.name,
      'programEnrollmentId': programEnrollmentId,
      // firestoreDocId is internal, not saved to DB field
    };
  }

  // ADD THIS FACTORY CONSTRUCTOR
  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'],
      clientId: json['clientId'],
      status: json['status'],
      sessionNo: json['sessionNo'],
      time: json['time'],
      date: json['date'],
      rating: json['rating'],
      comments: json['comments'],
      read: json['read'] ?? false,
      notifiedTwoHour: json['notifiedTwoHour'] ?? false,
      notifiedFiveMin: json['notifiedFiveMin'] ?? false,
      programType: json['programType'] != null
          ? ProgramTypeExtension.fromString(json['programType'])
          : null,
      courseName: json['courseName'],
      duration: json['duration'] != null
          ? SessionDurationExtension.fromString(json['duration'])
          : null,
      programEnrollmentId: json['programEnrollmentId'],
    );
  }
}
