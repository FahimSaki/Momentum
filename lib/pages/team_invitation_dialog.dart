import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momentum/services/user_service.dart';
import 'package:momentum/services/team_service.dart';
import 'package:momentum/models/user.dart';
import 'package:momentum/models/team.dart';
import 'package:momentum/database/task_database.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class TeamInvitationDialog extends StatefulWidget {
  final Team team;

  const TeamInvitationDialog({super.key, required this.team});

  @override
  State<TeamInvitationDialog> createState() => _TeamInvitationDialogState();
}

class _TeamInvitationDialogState extends State<TeamInvitationDialog>
    with TickerProviderStateMixin {
  final Logger _logger = Logger();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _inviteIdController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  late TabController _tabController;
  List<User> _searchResults = [];
  User? _selectedUser;
  User? _inviteIdUser;
  bool _isSearching = false;
  bool _isLoadingInviteId = false;
  bool _isSendingInvitation = false;
  String _selectedRole = 'member';
  String? _searchError;
  String? _inviteIdError;

  UserService? _userService;
  TeamService? _teamService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final db = Provider.of<TaskDatabase>(context, listen: false);
    if (db.jwtToken != null) {
      _userService = UserService(jwtToken: db.jwtToken!);
      _teamService = TeamService(jwtToken: db.jwtToken!);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _inviteIdController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        _searchResults.clear();
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      if (_userService == null) {
        throw Exception('User service not initialized');
      }

      final results = await _userService!.searchUsers(query.trim());

      // Filter out users already in the team
      final filteredResults = results.where((user) {
        return !widget.team.members.any((member) => member.user.id == user.id);
      }).toList();

      setState(() {
        _searchResults = filteredResults.cast<User>();
        _isSearching = false;
      });

      _logger.i('Found ${_searchResults.length} users for query: $query');
    } catch (e, stackTrace) {
      _logger.e('Error searching users', error: e, stackTrace: stackTrace);
      setState(() {
        _isSearching = false;
        _searchError =
            'Search failed: ${e.toString().replaceFirst('Exception: ', '')}';
        _searchResults.clear();
      });
    }
  }

  Future<void> _lookupUserByInviteId(String inviteId) async {
    if (inviteId.trim().isEmpty) {
      setState(() {
        _inviteIdUser = null;
        _inviteIdError = null;
      });
      return;
    }

    setState(() {
      _isLoadingInviteId = true;
      _inviteIdError = null;
    });

    try {
      if (_userService == null) {
        throw Exception('User service not initialized');
      }

      final user = await _userService!.getUserByInviteId(inviteId.trim());

      // Check if user is already a team member
      final isAlreadyMember = widget.team.members.any(
        (member) => member.user.id == user.id,
      );

      if (isAlreadyMember) {
        setState(() {
          _inviteIdUser = null;
          _inviteIdError = 'User is already a team member';
          _isLoadingInviteId = false;
        });
        return;
      }

      setState(() {
        _inviteIdUser = user;
        _isLoadingInviteId = false;
      });

      _logger.i('Found user by invite ID: ${user.name} (${user.inviteId})');
    } catch (e, stackTrace) {
      _logger.e(
        'Error looking up user by invite ID',
        error: e,
        stackTrace: stackTrace,
      );
      setState(() {
        _isLoadingInviteId = false;
        _inviteIdError =
            'User not found: ${e.toString().replaceFirst('Exception: ', '')}';
        _inviteIdUser = null;
      });
    }
  }

  Future<void> _sendInvitation() async {
    User? targetUser;
    String? targetEmail;
    String? targetInviteId;

    if (_tabController.index == 0) {
      // Email/search tab
      if (_selectedUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a user to invite')),
        );
        return;
      }
      targetUser = _selectedUser;
      targetEmail = _selectedUser!.email;
    } else {
      // Invite ID tab
      if (_inviteIdUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid invite ID')),
        );
        return;
      }
      targetUser = _inviteIdUser;
      targetInviteId = _inviteIdUser!.inviteId;
    }

    setState(() {
      _isSendingInvitation = true;
    });

    try {
      if (_teamService == null) {
        throw Exception('Team service not initialized');
      }

      await _teamService!.inviteToTeam(
        teamId: widget.team.id,
        email: targetEmail,
        inviteId: targetInviteId,
        role: _selectedRole,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      _logger.i('Invitation sent successfully to ${targetUser?.name}');

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation sent to ${targetUser?.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Error sending invitation', error: e, stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send invitation: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingInvitation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.group_add, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Invite to ${widget.team.name}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Search Users', icon: Icon(Icons.search)),
                Tab(text: 'Invite ID', icon: Icon(Icons.tag)),
              ],
            ),
            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildSearchTab(), _buildInviteIdTab()],
              ),
            ),

            const Divider(),

            // Role selection and message
            _buildInvitationOptions(),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSendingInvitation
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSendingInvitation ? null : _sendInvitation,
                    child: _isSendingInvitation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send Invitation'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search field
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search by name or email',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            errorText: _searchError,
          ),
          onChanged: (value) {
            // Debounce search
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_searchController.text == value) {
                _searchUsers(value);
              }
            });
          },
        ),
        const SizedBox(height: 16),

        // Search results
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.trim().isEmpty
                            ? 'Type to search for users'
                            : 'No users found',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final isSelected = _selectedUser?.id == user.id;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user.avatar != null
                              ? NetworkImage(user.avatar!)
                              : null,
                          child: user.avatar == null
                              ? Text(user.initials)
                              : null,
                        ),
                        title: Text(user.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (user.profileVisibility.showEmail &&
                                user.email.isNotEmpty)
                              Text(user.email),
                            Text(
                              'ID: ${user.inviteId}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            if (user.bio != null &&
                                user.bio!.isNotEmpty &&
                                user.profileVisibility.showBio)
                              Text(user.bio!, style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedUser = isSelected ? null : user;
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInviteIdTab() {
    return Column(
      children: [
        // Invite ID field
        TextField(
          controller: _inviteIdController,
          decoration: InputDecoration(
            labelText: 'Enter Invite ID',
            prefixIcon: const Icon(Icons.tag),
            border: const OutlineInputBorder(),
            errorText: _inviteIdError,
            suffixIcon: IconButton(
              onPressed: () async {
                final clipboardData = await Clipboard.getData('text/plain');
                if (clipboardData?.text != null) {
                  _inviteIdController.text = clipboardData!.text!;
                  _lookupUserByInviteId(clipboardData.text!);
                }
              },
              icon: const Icon(Icons.paste),
              tooltip: 'Paste from clipboard',
            ),
          ),
          onChanged: (value) {
            // Debounce lookup
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_inviteIdController.text == value) {
                _lookupUserByInviteId(value);
              }
            });
          },
        ),
        const SizedBox(height: 16),

        // User preview
        Expanded(
          child: _isLoadingInviteId
              ? const Center(child: CircularProgressIndicator())
              : _inviteIdUser != null
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundImage: _inviteIdUser!.avatar != null
                              ? NetworkImage(_inviteIdUser!.avatar!)
                              : null,
                          child: _inviteIdUser!.avatar == null
                              ? Text(
                                  _inviteIdUser!.initials,
                                  style: TextStyle(fontSize: 24),
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _inviteIdUser!.name,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (_inviteIdUser!.profileVisibility.showEmail &&
                            _inviteIdUser!.email.isNotEmpty)
                          Text(_inviteIdUser!.email),
                        Text(
                          'ID: ${_inviteIdUser!.inviteId}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        if (_inviteIdUser!.bio != null &&
                            _inviteIdUser!.bio!.isNotEmpty &&
                            _inviteIdUser!.profileVisibility.showBio)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _inviteIdUser!.bio!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.tag, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Enter an Invite ID to find a user',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildInvitationOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Role selection
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedRole = value;
                    });
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Message field
        TextField(
          controller: _messageController,
          decoration: const InputDecoration(
            labelText: 'Personal message (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          maxLength: 200,
        ),
      ],
    );
  }
}
