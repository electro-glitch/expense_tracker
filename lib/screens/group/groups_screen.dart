import 'package:expense_tracker/models/group_model.dart';
import 'package:expense_tracker/models/invitation_model.dart';
import 'package:expense_tracker/models/user_model.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) return const Scaffold();

    final groupsAsync = ref.watch(groupsStreamProvider(user.uid));
    final invitationsAsync = ref.watch(pendingInvitationsProvider(user.email ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            onPressed: () => _showCreateGroupDialog(context, ref, user.uid),
            icon: const Icon(Icons.group_add),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            invitationsAsync.when(
              data: (invites) => _buildInvitationsList(context, ref, invites.where((i) => i.type == 'group').toList(), user.uid),
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => Text('Error loading invites: $e'),
            ),
            groupsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return _buildNoGroupsView(context, ref, user.uid);
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return _GroupCard(group: group, currentUserId: user.uid);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
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
            'Group Invitations', 
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
                title: Text('${inv.fromName} invited you to join "${inv.groupName}"'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      onPressed: () => ref.read(firestoreServiceProvider).respondToInvitation(inv.id, 'accepted', uid, null),
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

  Widget _buildNoGroupsView(BuildContext context, WidgetRef ref, String uid) {
    return Container(
      height: 400,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.groups_outlined, size: 80, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          const Text('Split expenses with friends or colleagues.', style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateGroupDialog(context, ref, uid),
            icon: const Icon(Icons.add),
            label: const Text('Create New Group'),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupDialog(BuildContext context, WidgetRef ref, String uid) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Group Name', hintText: 'e.g. Goa Trip 🌴'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final group = GroupModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                members: [uid],
                balances: {uid: 0.0},
              );
              await ref.read(firestoreServiceProvider).createGroup(group);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  final GroupModel group;
  final String currentUserId;

  const _GroupCard({required this.group, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myBalance = group.balances[currentUserId] ?? 0.0;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      group.name,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showInviteDialog(context, ref),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${group.members.length} members',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    myBalance >= 0 ? (myBalance == 0 ? 'Settled up' : 'You are owed') : 'You owe',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '₹ ${myBalance.abs().toStringAsFixed(2)}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: myBalance == 0 ? theme.colorScheme.outline : (myBalance > 0 ? Colors.green : Colors.red),
                    ),
                  ),
                ],
              ),
              if (myBalance != 0) ...[
                const SizedBox(height: 8),
                _buildBalanceDetails(context, ref),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceDetails(BuildContext context, WidgetRef ref) {
    final myBalance = group.balances[currentUserId] ?? 0.0;
    final List<Widget> details = [];

    group.balances.forEach((uid, balance) {
      if (uid == currentUserId) return;
      
      if (myBalance < 0 && balance > 0) {
        details.add(
          FutureBuilder<UserModel?>(
            future: ref.read(firestoreServiceProvider).getUser(uid).first,
            builder: (context, snapshot) {
              final name = snapshot.data?.name ?? '...';
              return Text('You owe $name', style: const TextStyle(fontSize: 12, color: Colors.grey));
            },
          )
        );
      } else if (myBalance > 0 && balance < 0) {
        details.add(
          FutureBuilder<UserModel?>(
            future: ref.read(firestoreServiceProvider).getUser(uid).first,
            builder: (context, snapshot) {
              final name = snapshot.data?.name ?? '...';
              return Text('$name owes you', style: const TextStyle(fontSize: 12, color: Colors.grey));
            },
          )
        );
      }
    });

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: details);
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite to Group'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'Email Address', hintText: 'friend@example.com'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim().toLowerCase();
              if (email.isEmpty) return;
              
              final user = await ref.read(firestoreServiceProvider).getUserByEmail(email);
              if (user != null) {
                if (group.members.contains(user.uid)) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User is already in group')));
                   return;
                }
                final currentUser = ref.read(authServiceProvider).currentUser;
                final invitation = InvitationModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  toEmail: email,
                  groupId: group.id,
                  groupName: group.name,
                  fromName: currentUser?.displayName ?? currentUser?.email ?? 'Group Member',
                  status: 'pending',
                  type: 'group',
                );
                await ref.read(firestoreServiceProvider).sendInvitation(invitation);
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation sent!')));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not found')));
              }
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }
}
