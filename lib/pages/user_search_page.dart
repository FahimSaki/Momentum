import 'package:flutter/material.dart';
import 'package:momentum/models/user.dart';
import 'package:momentum/services/user_service.dart';
import 'package:momentum/database/task_database.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class UserSearchPage extends StatefulWidget {
  final String teamId;
  final String teamName;

  const UserSearchPage({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final Logger _logger = Logger();
  final _searchController = TextEditingController();
  final _inviteIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();

  List<User> searchResults = [];
  bool _isSearching = false;
  bool _showInviteIdSearch = false;
  bool _showEmailInvite = false;
  bool _isInviting = false;

  // Track which users have been invited in this session
  final Set<String> _invitedUserIds = {};

  late UserService _userService;

  @override
  void initState() {
    super.initState();
    final db = Provider.of<TaskDatabase>(context, listen: false);

    if (db.jwtToken == null || db.jwtToken!.isEmpty) {
      _logger.e('JWT token is null or empty');
      return;
    }

    _userService = UserService(jwtToken: db.jwtToken!);
    _logger.i('UserSearchPage initialized for team: ${widget.teamName}');
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inviteIdController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invite to ${widget.teamName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Options Tabs
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    'Search Users',
                    !_showInviteIdSearch && !_showEmailInvite,
                    () => setState(() {
                      _showInviteIdSearch = false;
                      _showEmailInvite = false;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton(
                    'Invite ID',
                    _showInviteIdSearch,
                    () => setState(() {
                      _showInviteIdSearch = true;
                      _showEmailInvite = false;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton(
                    'Email',
                    _showEmailInvite,
                    () => setState(() {
                      _showInviteIdSearch = false;
                      _showEmailInvite = true;
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Content based on selected tab
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_showInviteIdSearch) {
      return _buildInviteIdSearch();
    } else if (_showEmailInvite) {
      return _buildEmailInvite();
    } else {
      return _buildUserSearch();
    }
  }

  Widget _buildUserSearch() {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search by name or email',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              suffixIcon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            onChanged: _performSearch,
            enabled: !_isSearching && !_isInviting,
          ),
        ),

        const SizedBox(height: 16),

        // Search results
        Expanded(
          child: searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isEmpty
                            ? 'Start typing to search for users'
                            : _isSearching
                            ? 'Searching...'
                            : 'No users found',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: searchResults.length,
                  itemBuilder: (context, index) {
                    final user = searchResults[index];
                    // Check if already invited in this session
                    final wasInvited = _invitedUserIds.contains(user.id);

                    return _UserSearchTile(
                      user: user,
                      onInvite: () => _inviteUser(user),
                      isInviting: _isInviting,
                      wasAlreadyInvited: wasInvited,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInviteIdSearch() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter Invite ID',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask your friend for their unique invite ID (e.g., swift-tiger-1234)',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _inviteIdController,
            decoration: const InputDecoration(
              labelText: 'Invite ID (swift-tiger-1234)',
              prefixIcon: Icon(Icons.tag),
              border: OutlineInputBorder(),
              hintText: 'e.g., swift-tiger-1234',
            ),
            enabled: !_isInviting,
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Optional Message',
              border: OutlineInputBorder(),
              hintText: 'Hey! Join our team...',
            ),
            maxLines: 3,
            enabled: !_isInviting,
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isInviting ? null : _inviteByInviteId,
              child: _isInviting
                  ? const CircularProgressIndicator()
                  : const Text('Send Invitation'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailInvite() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite by Email',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Send an invitation to someone\'s email address',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
              hintText: 'friend@example.com',
            ),
            keyboardType: TextInputType.emailAddress,
            enabled: !_isInviting,
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Optional Message',
              border: OutlineInputBorder(),
              hintText: 'Hey! Join our team...',
            ),
            maxLines: 3,
            enabled: !_isInviting,
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isInviting ? null : _inviteByEmail,
              child: _isInviting
                  ? const CircularProgressIndicator()
                  : const Text('Send Email Invitation'),
            ),
          ),
        ],
      ),
    );
  }

  void _performSearch(String query) async {
    if (query.length < 2) {
      setState(() {
        searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      _logger.i('Searching for users with query: $query');
      final results = await _userService.searchUsers(query);
      _logger.i('Search returned ${results.length} results');

      if (mounted) {
        setState(() {
          searchResults = results.cast<User>();
          _isSearching = false;
        });
      }
    } catch (e, stackTrace) {
      _logger.e('Error searching users', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Better error handling
  void _inviteUser(User user) async {
    setState(() {
      _isInviting = true;
    });

    try {
      _logger.i('Inviting user: ${user.name} (${user.inviteId})');
      final db = Provider.of<TaskDatabase>(context, listen: false);
      await db.inviteToTeam(teamId: widget.teamId, inviteId: user.inviteId);

      // Track successful invitation
      _invitedUserIds.add(user.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Invitation sent to ${user.name}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Error inviting user', error: e, stackTrace: stackTrace);

      if (mounted) {
        // Better error messages
        String errorMessage = e.toString().replaceFirst('Exception: ', '');

        if (errorMessage.contains('already has a pending invitation')) {
          errorMessage =
              '${user.name} already has a pending invitation to this team';

          // Show dialog with option to check invitations
          _showPendingInvitationDialog(user.name);
        } else if (errorMessage.contains('already a team member')) {
          errorMessage = '${user.name} is already a member of this team';
        } else if (errorMessage.contains('Network error')) {
          errorMessage = 'Network error - check your connection';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInviting = false;
        });
      }
    }
  }

  // Show informative dialog for pending invitations
  void _showPendingInvitationDialog(String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('Pending Invitation'),
          ],
        ),
        content: Text(
          '$userName already has a pending invitation to this team.\n\n'
          'They need to accept or decline the existing invitation before you can send a new one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _inviteByInviteId() async {
    final inviteId = _inviteIdController.text.trim();

    if (inviteId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an invite ID')),
      );
      return;
    }

    setState(() {
      _isInviting = true;
    });

    try {
      _logger.i('Inviting by invite ID: $inviteId');
      final db = Provider.of<TaskDatabase>(context, listen: false);
      await db.inviteToTeam(
        teamId: widget.teamId,
        inviteId: inviteId,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Invitation sent to $inviteId!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Error inviting by invite ID',
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        String errorMessage = e.toString().replaceFirst('Exception: ', '');

        if (errorMessage.contains('already has a pending invitation')) {
          errorMessage = 'This user already has a pending invitation';
          _showPendingInvitationDialog('User');
        } else if (errorMessage.contains('not found')) {
          errorMessage = 'User not found with that invite ID';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInviting = false;
        });
      }
    }
  }

  void _inviteByEmail() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email address')),
      );
      return;
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() {
      _isInviting = true;
    });

    try {
      _logger.i('Inviting by email: $email');
      final db = Provider.of<TaskDatabase>(context, listen: false);
      await db.inviteToTeam(
        teamId: widget.teamId,
        email: email,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Email invitation sent to $email!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Error inviting by email', error: e, stackTrace: stackTrace);

      if (mounted) {
        String errorMessage = e.toString().replaceFirst('Exception: ', '');

        if (errorMessage.contains('already has a pending invitation')) {
          errorMessage = '$email already has a pending invitation';
          _showPendingInvitationDialog(email);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invitation: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInviting = false;
        });
      }
    }
  }
}

// User search tile with invitation tracking
class _UserSearchTile extends StatelessWidget {
  final User user;
  final VoidCallback onInvite;
  final bool isInviting;
  final bool wasAlreadyInvited;

  const _UserSearchTile({
    required this.user,
    required this.onInvite,
    this.isInviting = false,
    this.wasAlreadyInvited = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      // Visual indicator if already invited
      color: wasAlreadyInvited ? Colors.green.withValues(alpha: 0.1) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.2),
          backgroundImage: user.avatar != null && user.avatar!.isNotEmpty
              ? NetworkImage(user.avatar!)
              : null,
          child: user.avatar == null || user.avatar!.isEmpty
              ? Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            // Show invited badge
            if (wasAlreadyInvited)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'INVITED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.profileVisibility.showEmail && user.email.isNotEmpty)
              Text(user.email),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'ID: ${user.inviteId}',
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            if (user.bio != null &&
                user.bio!.isNotEmpty &&
                user.profileVisibility.showBio) ...[
              const SizedBox(height: 4),
              Text(
                user.bio!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: wasAlreadyInvited
            ? Icon(Icons.check_circle, color: Colors.green)
            : ElevatedButton(
                onPressed: isInviting ? null : onInvite,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: isInviting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Invite'),
              ),
        onTap: isInviting || wasAlreadyInvited
            ? null
            : () {
                _showUserDetailsDialog(context, user);
              },
      ),
    );
  }

  void _showUserDetailsDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user.profileVisibility.showEmail && user.email.isNotEmpty) ...[
              Text('📧 ${user.email}'),
              const SizedBox(height: 8),
            ],
            Text('🔖 ID: ${user.inviteId}'),
            if (user.bio != null &&
                user.bio!.isNotEmpty &&
                user.profileVisibility.showBio) ...[
              const SizedBox(height: 8),
              Text('💬 ${user.bio!}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!wasAlreadyInvited)
            ElevatedButton(
              onPressed: isInviting
                  ? null
                  : () {
                      Navigator.pop(context);
                      onInvite();
                    },
              child: const Text('Send Invite'),
            ),
        ],
      ),
    );
  }
}
