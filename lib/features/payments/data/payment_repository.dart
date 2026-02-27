import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../models/payment_plan.dart';
import '../../../../models/payment_entry.dart';
import '../../../../core/config/app_config.dart'; // NEW

class PaymentRepository {
  final FirebaseFirestore _firestore;

  PaymentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  String get _userId => AppConfig.sharedWorkspaceId;

  CollectionReference<PaymentPlan> get _plansRef =>
      _firestore.collection('users').doc(_userId).collection('payment_plans').withConverter<PaymentPlan>(
            fromFirestore: (snapshot, _) {
              final data = snapshot.data()!;
              data['id'] = snapshot.id; // Ensure ID matches doc ID
              return PaymentPlan.fromJson(data);
            },
            toFirestore: (plan, _) {
               var json = plan.toJson();
               json.remove('id'); // ID is the key, doesn't strictly need to be in body, but keep it if preferred. Firestore converter usually ignores return id? No, setId does it.
               return json;
            },
          );

  CollectionReference<PaymentEntry> get _entriesRef =>
      _firestore.collection('users').doc(_userId).collection('payment_entries').withConverter<PaymentEntry>(
            fromFirestore: (snapshot, _) {
              final data = snapshot.data()!;
              data['id'] = snapshot.id;
              return PaymentEntry.fromJson(data);
            },
            toFirestore: (entry, _) {
               var json = entry.toJson();
               json.remove('id');
               return json;
            },
          );

  // --- Payment Plans ---

  Stream<List<PaymentPlan>> getPaymentPlans(int clientId) {
    return _plansRef
        .where('clientId', isEqualTo: clientId)
        .where('active', isEqualTo: true) // Only active plans usually
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  Future<String> addPaymentPlan(PaymentPlan plan) async {
    final docRef = await _plansRef.add(plan);
    // Determine and create initial entries based on frequency? 
    // Usually, the UI or Business Logic Layer decides to generate entries. 
    // But we can do it here transactionally if we want.
    // For now, let's just return the ID.
    return docRef.id; 
  }

  Future<void> updatePaymentPlan(PaymentPlan plan) async {
    await _plansRef.doc(plan.id).set(plan);
  }

  Future<void> replacePaymentPlan(PaymentPlan plan, List<PaymentEntry> newEntries) async {
    final batch = _firestore.batch();
    
    // 1. Update Plan
    batch.set(_plansRef.doc(plan.id), plan);
    
    // 2. Delete ALL existing entries for this plan (Full Reset)
    // Note: We need to query them first. To ensure atomicity within limits, we fetch then batch delete.
    final existingParams = await _entriesRef.where('planId', isEqualTo: plan.id).get();
    for (final doc in existingParams.docs) {
      batch.delete(doc.reference);
    }
    
    // 3. Add New Entries
    for (final entry in newEntries) {
       final docRef = _entriesRef.doc(); // Generate new ID
       final entryWithId = entry.copyWith(id: docRef.id, planId: plan.id);
       batch.set(docRef, entryWithId);
    }
    
    await batch.commit();
  }

  Future<void> deletePaymentPlan(String planId) async {
    // Also delete associated entries? Or keep them as history?
    // Requirement says "User can delete: Entire payment plan". Usually implies cascading delete of future entries at least.
    // Let's mark as inactive instead? Or delete. 
    // "Delete... Entire payment plan" -> Delete.
    
    final batch = _firestore.batch();
    
    // Delete plan
    batch.delete(_plansRef.doc(planId));
    
    // Delete entries for this plan
    final entries = await _entriesRef.where('planId', isEqualTo: planId).get();
    for (final doc in entries.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
  }

  // --- Payment Entries ---

  Stream<List<PaymentEntry>> getPaymentEntries(int clientId) {
    return _entriesRef
        .where('clientId', isEqualTo: clientId)
        .snapshots() // Ordering might need to be done in memory or composite index
        .map((s) {
           final list = s.docs.map((d) => d.data()).toList();
           // Sort by due date
           list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
           return list;
        });
  }
  
  Stream<List<PaymentEntry>> getEntriesForPlan(String planId) {
    return _entriesRef
        .where('planId', isEqualTo: planId)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate)));
  }

  Future<void> addPaymentEntry(PaymentEntry entry) async {
    final docRef = _entriesRef.doc(); // Generate ID
    final entryWithId = entry.copyWith(id: docRef.id);
    await docRef.set(entryWithId);
  }
  
  Future<void> addPaymentEntriesBatch(List<PaymentEntry> entries) async {
    final batch = _firestore.batch();
    for (final entry in entries) {
       final docRef = _entriesRef.doc(); 
       final entryWithId = entry.copyWith(id: docRef.id);
       batch.set(docRef, entryWithId);
    }
    await batch.commit();
  }

  Future<void> updatePaymentEntry(PaymentEntry entry) async {
    await _entriesRef.doc(entry.id).set(entry);
  }

  Future<void> deletePaymentEntry(String entryId) async {
    await _entriesRef.doc(entryId).delete();
  }
  // --- Global Payment Access for Dashboard ---
  
  Stream<List<PaymentEntry>> getAllPendingPaymentEntries() async* {
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

    yield* _entriesRef
        .where('clientId', isEqualTo: clientId)
        .snapshots() 
        .map((s) {
           final list = s.docs
               .map((d) => d.data())
               .where((e) => e.status != PaymentStatus.paid) 
               .toList();
           list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
           return list;
        });
  }

  Future<void> updatePaymentEntriesBatch(List<PaymentEntry> entries) async {
    final batch = _firestore.batch();
    for (final entry in entries) {
      batch.set(_entriesRef.doc(entry.id), entry);
    }
    await batch.commit();
  }
}
