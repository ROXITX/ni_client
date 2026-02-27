import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../models/client.dart';
import '../../../models/session.dart';
import '../../../models/course.dart';
import '../../core/config/app_config.dart'; // NEW

class AppointmentRepository {
  final FirebaseFirestore _firestore;

  AppointmentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // --- Collection References ---
  // UNIFIED VIEW CHANGE: Use Shared Workspace ID for everyone
  String get _userId => AppConfig.sharedWorkspaceId;

  CollectionReference<Client> get _clientsRef =>
      _firestore.collection('users').doc(_userId).collection('clients').withConverter<Client>(
            fromFirestore: (snapshot, _) => Client.fromJson(snapshot.data()!),
            toFirestore: (client, _) => client.toJson(),
          );

  CollectionReference<Session> get _sessionsRef =>
      _firestore.collection('users').doc(_userId).collection('sessions').withConverter<Session>(
            fromFirestore: (snapshot, _) {
               final s = Session.fromJson(snapshot.data()!);
               s.firestoreDocId = snapshot.id;
               return s;
            },
            toFirestore: (session, _) => session.toJson(),
          );

  CollectionReference<Course> get _coursesRef =>
      _firestore.collection('users').doc(_userId).collection('courses').withConverter<Course>(
            fromFirestore: (snapshot, _) => Course.fromJson(snapshot.data()!),
            toFirestore: (course, _) => course.toJson(),
          );

  // --- Streams ---
  Stream<List<Client>> getClients() async* {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      yield [];
      return;
    }
    yield* _clientsRef
        .snapshots()
        .map((snapshot) {
           final clients = snapshot.docs.map((doc) => doc.data()).toList();
           return clients.where((client) => client.email.toLowerCase() == email.toLowerCase()).toList();
        });
  }

  Stream<List<Session>> getSessions() async* {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) {
      yield [];
      return;
    }

    final query = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('clients')
        .get();

    final matchingClients = query.docs.where((doc) => 
       (doc.data()['email'] as String).toLowerCase() == email.toLowerCase()
    );

    if (matchingClients.isEmpty) {
      yield [];
      return;
    }

    final int clientId = matchingClients.first.data()['id'];

    yield* _sessionsRef.where('clientId', isEqualTo: clientId).snapshots().map((snapshot) {
      final uniqueSessions = <String, Session>{};
      
      for (var doc in snapshot.docs) {
        final s = doc.data();
        final progId = s.programEnrollmentId ?? s.programType?.name ?? 'General';
        
        // Composite Key 
        final key = '${s.clientId}_${progId}_${s.date}_${s.time}_${s.id}';
        
        uniqueSessions[key] = s;
      }
      return uniqueSessions.values.toList();
    });
  }

  Stream<List<Course>> getCourses() {
    return _coursesRef.snapshots().map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  // --- CRUD Operations ---
  Future<void> addClient(Client client) async {
    await _clientsRef.doc(client.id.toString()).set(client);
  }

  Future<void> updateClient(Client client) async {
    await _clientsRef.doc(client.id.toString()).set(client);
  }

  Future<void> addCourse(Course course) async {
    await _coursesRef.doc(course.id.toString()).set(course);
  }

  Future<void> updateCourse(Course course) async {
    await _coursesRef.doc(course.id.toString()).set(course);
  }

  Future<void> addSession(Session session) async {
    // If id is 0 or null, let Firestore generate? Model has int id.
    // Original code: await _sessionsRef.add(session.toJson()); -> Firestore generates Doc ID.
    // BUT Session model has 'id' field (int).
    // Original code 'home_page.dart' :
    // final newSession = Session(id: <random int?>, ...)
    // Wait, let's check home_page.dart logic for ID generation for sessions.
    // Lines 4607+: 
    // final s = Session(id: DateTime.now().millisecondsSinceEpoch + index, ...)
    // await _sessionsRef.doc(s.id.toString()).set(s);
    // OR await _sessionsRef.add(...) // if no ID?
    // Let's assume we set ID before passing to addSession.
    await _sessionsRef.doc(session.id.toString()).set(session);
  }

  Future<void> updateSession(Session session) async {
    final docId = session.firestoreDocId ?? session.id.toString();
    await _sessionsRef.doc(docId).set(session);
  }
  
  Future<void> deleteSession(int sessionId) async {
    await _sessionsRef.doc(sessionId.toString()).delete();
  }

  Future<void> deleteClient(int clientId) async {
    final batch = _firestore.batch();
    
    // 1. Find all sessions for this client
    final sessionsSnapshot = await _sessionsRef.where('clientId', isEqualTo: clientId).get();
    
    // 2. Add session deletions to batch
    for (final doc in sessionsSnapshot.docs) {
      batch.delete(doc.reference);
    }
    
    // 3. Add client deletion to batch
    batch.delete(_clientsRef.doc(clientId.toString()));
    
    // 4. Commit
    await batch.commit();
  }

  Future<void> deleteCourse(int courseId) async {
    await _coursesRef.doc(courseId.toString()).delete();
  }

  // --- Validation ---
  Future<void> validateEmailUniqueness(String email, List<Client> clients, {int? excludeClientId}) async {
    if (email.trim().isEmpty) {
      if (excludeClientId != null) return; // Allow empty if editing ?? (Logic preserved from original)
      throw Exception('Email address is required');
    }

    final emailLower = email.trim().toLowerCase();
    final bool emailExists = clients.any((client) =>
        client.email.toLowerCase() == emailLower &&
        (excludeClientId == null || client.id != excludeClientId));

    if (emailExists) {
      throw Exception('A client with this email address already exists. Please use a different email.');
    }
  }

  Future<void> validateCourseNameUniqueness(String name, List<Course> courses, {int? excludeCourseId}) async {
    if (name.trim().isEmpty) {
       throw Exception('Course name is required');
    }

    final nameLower = name.trim().toLowerCase();
    final bool exists = courses.any((c) =>
        c.name.toLowerCase() == nameLower &&
        (excludeCourseId == null || c.id != excludeCourseId));

    if (exists) {
      throw Exception('A course with this name already exists.');
    }
  }

  // --- CSV Import ---
  // --- CSV Import Analysis ---
  Future<CsvImportResult> analyzeCsvImport() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, 
      );

      if (result == null) return CsvImportResult(errorMessage: 'No file selected');

      String csvString;
      if (kIsWeb) {
        final bytes = result.files.first.bytes;
        if (bytes == null) return CsvImportResult(errorMessage: 'Error reading file data');
        csvString = const Utf8Decoder().convert(bytes);
      } else {
        final path = result.files.single.path;
        if (path == null) return CsvImportResult(errorMessage: 'Error reading file path');
        final file = File(path);
        csvString = await file.readAsString();
      }

      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
      if (rows.isEmpty || rows.length < 2) return CsvImportResult(errorMessage: 'CSV file is empty or missing headers');

      final snapshot = await _clientsRef.get();
      final currentClients = snapshot.docs.map((d) => d.data()).toList();
      int nextId = currentClients.isEmpty ? 1 : (currentClients.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1);
      
      final safeClients = <Client>[];
      final conflictingClients = <Client>[];
      int skipCount = 0;

      final headers = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      final requiredHeaders = ['first name', 'last name', 'email'];
      for (final req in requiredHeaders) {
        if (!headers.contains(req)) return CsvImportResult(errorMessage: 'Missing required column: $req');
      }

      String getValue(List<dynamic> row, String colName) {
        final index = headers.indexOf(colName);
        if (index == -1 || index >= row.length) return '';
        return row[index].toString().trim();
      }

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty) continue;

        final email = getValue(row, 'email');
        if (email.isEmpty) continue; 

        // 1. Strict Email Duplicate Check (Skip silently or count as skipped)
        if (currentClients.any((c) => c.email.toLowerCase() == email.toLowerCase())) {
          skipCount++;
          continue;
        }

        final firstName = getValue(row, 'first name');
        final lastName = getValue(row, 'last name');

        final client = Client(
          id: nextId++, // Tentative ID
          firstName: firstName,
          lastName: lastName,
          dob: getValue(row, 'dob'),
          gender: getValue(row, 'gender'),
          email: email,
          phone: getValue(row, 'phone'),
          occupation: getValue(row, 'occupation'),
          description: getValue(row, 'description'),
          programs: [],
        );

        // 2. Name Conflict Check (Add to potential duplicates)
        bool nameExists = currentClients.any((c) => 
            c.firstName.toLowerCase() == firstName.toLowerCase() && 
            c.lastName.toLowerCase() == lastName.toLowerCase());
        
        // Also check against already processed clients in this batch to avoid internal duplicates
        bool inSafe = safeClients.any((c) => c.firstName.toLowerCase() == firstName.toLowerCase() && c.lastName.toLowerCase() == lastName.toLowerCase());
        bool inConflict = conflictingClients.any((c) => c.firstName.toLowerCase() == firstName.toLowerCase() && c.lastName.toLowerCase() == lastName.toLowerCase());

        if (nameExists || inSafe || inConflict) {
           conflictingClients.add(client);
        } else {
           safeClients.add(client);
        }
      }

      return CsvImportResult(
        safeClients: safeClients,
        conflictingClients: conflictingClients,
        emailDuplicatesSkipped: skipCount,
      );

    } catch (e) {
      return CsvImportResult(errorMessage: 'Error analyzing CSV: $e');
    }
  }

  Future<void> saveImportedClients(List<Client> clients) async {
     // Re-fetch next ID to be safe or trust the passed IDs? 
     // Trusting passed IDs for now to verify "safe" vs "conflict" resolution kept distinct.
     // But wait, if we merge lists, IDs might collide if generated sequentially in analysis?
     // Analysis generated IDs sequentially across the whole set (safe + conflict).
     // As long as we save the subset, IDs are unique.
     // However, they might clash with DB if DB changed.
     // Ideally we re-assign IDs here.
     
     final snapshot = await _clientsRef.get();
     final dbClients = snapshot.docs.map((d) => d.data()).toList();
     int nextId = dbClients.isEmpty ? 1 : (dbClients.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1);

     final batch = _firestore.batch();
     for (final client in clients) {
        // Update ID to ensure uniqueness at commit time
        final newClient = client.copyWith(id: nextId++);
        final docRef = _clientsRef.doc(newClient.id.toString());
        batch.set(docRef, newClient);
     }
     await batch.commit();
  }

  Future<void> updateSessionsBatch(List<Session> sessions) async {
    final batch = _firestore.batch();
    for (final session in sessions) {
      final docId = session.firestoreDocId ?? session.id.toString();
      final docRef = _sessionsRef.doc(docId);
      batch.set(docRef, session, SetOptions(merge: true));
    }
    await batch.commit();
  }

}

class CsvImportResult {
  final List<Client> safeClients;
  final List<Client> conflictingClients;
  final int emailDuplicatesSkipped;
  final String? errorMessage;
  
  CsvImportResult({
    this.safeClients = const [], 
    this.conflictingClients = const [], 
    this.emailDuplicatesSkipped = 0,
    this.errorMessage
  });
}
