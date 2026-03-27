import 'package:expense_tracker/models/family_model.dart';
import 'package:expense_tracker/models/invitation_model.dart';
import 'package:expense_tracker/models/user_model.dart';
import 'package:expense_tracker/screens/family/member_details_sheet.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) return const Scaffold();

    final familyAsync = ref.watch(familyStreamProvider(user.uid));
    final invitationsAsync = ref.watch(pendingInvitationsProvider(user.email ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Family'),
        centerTitle: false,
        actions: [
          familyAsync.when(
            data: (family) => family != null && family.creatorId == user.uid
                ? IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () => _confirmDeleteFamily(context, ref, family.id),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            invitationsAsync.when(
              data: (invites) => _buildInvitationsList(
                context, 
                ref, 
                invites.where((i) => i.type == 'family').toList(), 
                user.uid
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => Text('Error loading invites: $e'),
            ),
            familyAsync.when(
              data: (family) {
                if (family == null) {
                  return _buildNoFamilyView(context, ref, user.uid);
                }
                return _buildFamilyMembersView(context, ref, family, user.uid);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFamily(BuildContext context, WidgetRef ref, String familyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Family?'),
        content: const Text('This will dissolve the family group for everyone. Expenses will not be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(firestoreServiceProvider).deleteFamily(familyId);
    }
  }

  Widget _buildInvitationsList(BuildContext context, WidgetRef ref, List<InvitationModel> invites, String uid) {
    if (invites.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Family Invitations', 
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)
          ),
        ),
        ...invites.map((inv) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.2))
              ),
              child: ListTile(
                title: Text('${inv.fromName} invited you to join "${inv.familyName ?? "Family"}"'),
                subtitle: Text('Relationship: ${inv.relationship ?? "Member"}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      onPressed: () => ref.read(firestoreServiceProvider).respondToInvitation(inv.id, 'accepted', uid, inv.relationship),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                      onPressed: () => ref.read(firestoreServiceProvider).respondToInvitation(inv.id, 'declined', null, null),
                    ),
                  ],
                ),
              ),
            )),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildNoFamilyView(BuildContext context, WidgetRef ref, String uid) {
    return Container(
      height: 400,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.family_restroom, size: 80, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          const Text('Manage expenses with your family.', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateFamilyDialog(context, ref, uid),
            icon: const Icon(Icons.add),
            label: const Text('Create New Family'),
          ),
        ],
      ),
    );
  }

  Widget _buildFamilyMembersView(BuildContext context, WidgetRef ref, FamilyModel family, String currentUid) {
    final bool currentIsAdmin = family.admins.contains(currentUid);
    final bool isCreator = family.creatorId == currentUid;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(family.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              if (currentIsAdmin)
                ElevatedButton.icon(
                  onPressed: () => _showAddMemberDialog(context, ref, family, currentUid),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Invite'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Members', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          ...family.members.map((mUid) => _MemberTile(
                uid: mUid,
                family: family,
                currentUid: currentUid,
                isAdmin: family.admins.contains(mUid),
                isCreator: family.creatorId == mUid,
                canManageRoles: isCreator,
                canViewExpenses: currentIsAdmin || mUid == currentUid,
              )),
        ],
      ),
    );
  }

  void _showCreateFamilyDialog(BuildContext context, WidgetRef ref, String uid) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Family Name'),
        content: TextField(controller: nameController, decoration: const InputDecoration(hintText: 'e.g. The Smiths')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final family = FamilyModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                members: [uid],
                admins: [uid],
                creatorId: uid,
                relationships: {uid: 'Creator'},
              );
              await ref.read(firestoreServiceProvider).createFamily(family);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref, FamilyModel family, String currentUid) {
    final emailController = TextEditingController();
    final List<String> relations = ['Spouse', 'Parent', 'Child', 'Sibling', 'Other'];
    String selectedRelationship = relations[0]; 

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController, 
                decoration: const InputDecoration(labelText: 'Email Address', hintText: 'user@example.com')
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRelationship,
                items: relations.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => selectedRelationship = v!),
                decoration: const InputDecoration(labelText: 'Relationship'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim().toLowerCase();
                if (email.isEmpty) return;

                final user = await ref.read(firestoreServiceProvider).getUserByEmail(email);
                if (user != null) {
                  final currentUser = ref.read(authServiceProvider).currentUser;
                  final invitation = InvitationModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    toEmail: email,
                    familyId: family.id,
                    familyName: family.name,
                    fromName: currentUser?.displayName ?? currentUser?.email ?? 'Family Member',
                    relationship: selectedRelationship,
                    status: 'pending',
                    type: 'family',
                  );
                  await ref.read(firestoreServiceProvider).sendInvitation(invitation);
                  if (context.mounted) Navigator.pop(context);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User email not registered')));
                  }
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final String uid;
  final FamilyModel family;
  final String currentUid;
  final bool isAdmin;
  final bool isCreator;
  final bool canManageRoles;
  final bool canViewExpenses;

  const _MemberTile({
    required this.uid,
    required this.family,
    required this.currentUid,
    required this.isAdmin,
    required this.isCreator,
    required this.canManageRoles,
    required this.canViewExpenses,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return FutureBuilder<UserModel?>(
      future: ref.read(firestoreServiceProvider).getUser(uid).first,
      builder: (context, snapshot) {
        final user = snapshot.data;
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))
          ),
          child: ListTile(
            onTap: canViewExpenses ? () => _showMemberDetails(context, user?.name ?? 'Member') : null,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                user?.name.characters.first.toUpperCase() ?? 'U',
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              )
            ),
            title: Text(user?.name ?? 'Loading...', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${family.relationships[uid] ?? ""} • ${isAdmin ? "Admin" : "Member"}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (canManageRoles && !isCreator)
                  TextButton(
                    onPressed: () => ref.read(firestoreServiceProvider).toggleAdminRole(family.id, uid, !isAdmin),
                    child: Text(isAdmin ? 'Make Member' : 'Make Admin'),
                  ),
                if (canManageRoles && !isCreator)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _confirmRemoveMember(context, ref),
                  ),
                if (isCreator)
                  Chip(
                    label: const Text('Creator', style: TextStyle(fontSize: 10)),
                    backgroundColor: theme.colorScheme.secondaryContainer,
                  ),
                if (!canManageRoles && canViewExpenses && !isCreator)
                  const Icon(Icons.chevron_right),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRemoveMember(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: const Text('Are you sure you want to remove this person from the family?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(firestoreServiceProvider).removeFamilyMember(family.id, uid);
    }
  }

  void _showMemberDetails(BuildContext context, String memberName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemberDetailsSheet(uid: uid, name: memberName),
    );
  }
}
