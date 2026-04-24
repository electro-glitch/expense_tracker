import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/user_model.dart';
import 'package:expense_tracker/models/expense_model.dart';
import 'package:expense_tracker/models/family_model.dart';
import 'package:expense_tracker/models/group_model.dart';
import 'package:expense_tracker/models/invitation_model.dart';
import 'package:expense_tracker/models/budget_model.dart';
import 'package:expense_tracker/services/notification_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return FirestoreService(notificationService);
});

final familyStreamProvider = StreamProvider.family<FamilyModel?, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getFamily(userId);
});

final groupsStreamProvider = StreamProvider.family<List<GroupModel>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getUserGroups(userId);
});

final pendingInvitationsProvider = StreamProvider.family<List<InvitationModel>, String>((ref, email) {
  return ref.watch(firestoreServiceProvider).getPendingInvitations(email);
});

final budgetsStreamProvider = StreamProvider.family<List<BudgetModel>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getBudgets(userId);
});

final expensesStreamProvider = StreamProvider.family<List<ExpenseModel>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getExpenses(userId);
});

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService;

  FirestoreService(this._notificationService);

  // User methods
  Future<void> createUser(UserModel user) async {
    await _db.collection('users').doc(user.uid).set(user.toJson());
  }

  Stream<UserModel> getUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snapshot) {
      return UserModel.fromJson(snapshot.data() as Map<String, dynamic>);
    });
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final snapshot = await _db.collection('users').where('email', isEqualTo: email).get();
    if (snapshot.docs.isNotEmpty) {
      return UserModel.fromJson(snapshot.docs.first.data());
    }
    return null;
  }

  // Expense methods
  Future<void> addExpense(ExpenseModel expense) async {
    // Save expense first
    await _db.collection('expenses').doc(expense.id).set(expense.toJson());

    // Schedule a reminder notification for 10 hours from now
    await _notificationService.scheduleReminder();

    // If part of a group, update balances via transaction
    if (expense.groupId != null) {
      try {
        await _db.runTransaction((transaction) async {
          final groupRef = _db.collection('groups').doc(expense.groupId);
          final groupDoc = await transaction.get(groupRef);
          
          if (groupDoc.exists) {
            final groupData = groupDoc.data()!;
            final List<String> members = List<String>.from(groupData['members'] ?? []);
            final Map<String, dynamic> rawBalances = Map<String, dynamic>.from(groupData['balances'] ?? {});
            
            final amount = expense.amount;
            final payerId = expense.userId;
            
            final splitWithIds = (expense.splitWith != null && expense.splitWith!.isNotEmpty) 
                ? expense.splitWith! 
                : members;
            
            final splitCount = splitWithIds.length;
            if (splitCount > 0) {
              final splitAmount = amount / splitCount;
              final Map<String, double> updatedBalances = rawBalances.map(
                (key, value) => MapEntry(key, (value as num).toDouble()),
              );
              
              for (var m in members) {
                updatedBalances.putIfAbsent(m, () => 0.0);
              }

              updatedBalances[payerId] = (updatedBalances[payerId] ?? 0.0) + amount;
              
              for (final memberId in splitWithIds) {
                updatedBalances[memberId] = (updatedBalances[memberId] ?? 0.0) - splitAmount;
              }
              
              transaction.update(groupRef, {'balances': updatedBalances});
            }
          }
        });
      } catch (e) {
        print('Transaction failed: $e');
        rethrow;
      }
    }
  }

  Future<void> settleDebt(String groupId, String fromId, String toId, double amount) async {
    try {
      await _db.runTransaction((transaction) async {
        final groupRef = _db.collection('groups').doc(groupId);
        final groupDoc = await transaction.get(groupRef);
        
        if (groupDoc.exists) {
          final groupData = groupDoc.data()!;
          final Map<String, dynamic> rawBalances = Map<String, dynamic>.from(groupData['balances'] ?? {});
          
          final Map<String, double> updatedBalances = rawBalances.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          );
          
          // 'fromId' is paying back, so their debt decreases (balance goes up)
          updatedBalances[fromId] = (updatedBalances[fromId] ?? 0.0) + amount;
          // 'toId' is receiving, so their credit decreases (balance goes down)
          updatedBalances[toId] = (updatedBalances[toId] ?? 0.0) - amount;
          
          transaction.update(groupRef, {'balances': updatedBalances});
          
          // Optional: Record this as a special settlement transaction in expenses
          final settlementId = DateTime.now().millisecondsSinceEpoch.toString();
          final settlementExpense = ExpenseModel(
            id: settlementId,
            userId: fromId,
            amount: amount,
            category: 'Settlement 🤝',
            date: DateTime.now(),
            note: 'Settled debt with group member',
            type: TransactionType.expense, // Mark as expense for the payer
            groupId: groupId,
          );
          transaction.set(_db.collection('expenses').doc(settlementId), settlementExpense.toJson());
        }
      });
    } catch (e) {
      print('Settle Debt failed: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    await _db.collection('expenses').doc(expenseId).delete();
  }

  Stream<List<ExpenseModel>> getExpenses(String userId) {
    return _db
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final expenses = snapshot.docs.map((doc) => ExpenseModel.fromJson(doc.data())).toList();
      expenses.sort((a, b) => b.date.compareTo(a.date));
      return expenses;
    });
  }

  // Family methods
  Future<void> createFamily(FamilyModel family) async {
    await _db.collection('families').doc(family.id).set(family.toJson());
  }

  Future<void> deleteFamily(String familyId) async {
    await _db.collection('families').doc(familyId).delete();
  }

  Future<void> removeFamilyMember(String familyId, String memberUid) async {
    await _db.collection('families').doc(familyId).update({
      'members': FieldValue.arrayRemove([memberUid]),
      'admins': FieldValue.arrayRemove([memberUid]),
      'relationships.$memberUid': FieldValue.delete(),
    });
  }

  Stream<FamilyModel?> getFamily(String userId) {
    return _db
        .collection('families')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return FamilyModel.fromJson(snapshot.docs.first.data());
      }
      return null;
    });
  }

  // Group methods
  Future<void> createGroup(GroupModel group) async {
    await _db.collection('groups').doc(group.id).set(group.toJson());
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.collection('groups').doc(groupId).delete();
  }

  Stream<List<GroupModel>> getUserGroups(String userId) {
    return _db
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GroupModel.fromJson(doc.data())).toList());
  }

  // Budget methods
  Future<void> setBudget(BudgetModel budget) async {
    await _db.collection('budgets').doc(budget.id).set(budget.toJson());
  }

  Stream<List<BudgetModel>> getBudgets(String userId) {
    return _db
        .collection('budgets')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => BudgetModel.fromJson(doc.data())).toList());
  }

  // Invitation methods
  Future<void> sendInvitation(InvitationModel invitation) async {
    await _db.collection('invitations').doc(invitation.id).set(invitation.toJson());
  }

  Stream<List<InvitationModel>> getPendingInvitations(String email) {
    return _db
        .collection('invitations')
        .where('toEmail', isEqualTo: email)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InvitationModel.fromJson(doc.data()))
            .where((inv) => inv.status == 'pending')
            .toList());
  }

  Future<void> respondToInvitation(String invitationId, String status, String? userId, String? relationship) async {
    final invRef = _db.collection('invitations').doc(invitationId);
    final invDoc = await invRef.get();
    if (!invDoc.exists) return;

    final inv = InvitationModel.fromJson(invDoc.data()!);
    
    if (status == 'accepted' && userId != null) {
      if (inv.type == 'family' && inv.familyId != null) {
        await _db.collection('families').doc(inv.familyId).update({
          'members': FieldValue.arrayUnion([userId]),
          'relationships.$userId': relationship ?? inv.relationship,
        });
      } else if (inv.type == 'group' && inv.groupId != null) {
        await _db.collection('groups').doc(inv.groupId).update({
          'members': FieldValue.arrayUnion([userId]),
          'balances.$userId': 0.0,
        });
      }
    }
    
    await invRef.update({'status': status});
  }

  Future<void> toggleAdminRole(String familyId, String userId, bool isAdmin) async {
    await _db.collection('families').doc(familyId).update({
      'admins': isAdmin ? FieldValue.arrayUnion([userId]) : FieldValue.arrayRemove([userId]),
    });
  }
}
