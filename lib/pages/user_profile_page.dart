import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momentum/models/user.dart';
import 'package:momentum/services/user_service.dart';
import 'package:momentum/database/task_database.dart'; // ✅ ADD THIS
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final Logger _logger = Logger();
  User? currentUser;
  UserService? _userService;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() async {
    try {
      // Add type parameter
      final db = Provider.of<TaskDatabase>(context, listen: false);

      // Check if JWT token exists
      if (db.jwtToken == null || db.jwtToken!.isEmpty) {
        _logger.e('JWT token is null or empty');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Authentication error. Please login again.';
          });
        }
        return;
      }

      _userService = UserService(jwtToken: db.jwtToken!);
      _logger.i(
        'Loading user profile with token: ${db.jwtToken!.substring(0, 20)}...',
      );

      final user = await _userService!.getCurrentUserProfile();

      if (mounted) {
        setState(() {
          currentUser = user;
          _isLoading = false;
          _errorMessage = null;
        });
        _logger.i('User profile loaded successfully: ${user.name}');
      }
    } catch (e, stackTrace) {
      _logger.e('Error loading user profile', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load profile: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // REFRESH BUTTON
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _loadUserProfile();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading your profile...'),
                ],
              ),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUserProfile,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // Navigate to login
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (route) => false);
                    },
                    child: const Text('Go to Login'),
                  ),
                ],
              ),
            )
          : currentUser == null
          ? const Center(child: Text('Failed to load profile'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  _buildInviteIdCard(),
                  const SizedBox(height: 16),
                  _buildPrivacySettings(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.withValues(alpha: 0.2),
              backgroundImage: currentUser!.avatar != null
                  ? NetworkImage(currentUser!.avatar!)
                  : null,
              child: currentUser!.avatar == null
                  ? Text(
                      currentUser!.initials,
                      style: const TextStyle(
                        fontSize: 36,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              currentUser!.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              currentUser!.email,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            if (currentUser!.bio != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(currentUser!.bio!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInviteIdCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.tag, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Your Invite ID',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      currentUser!.inviteId,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: currentUser!.inviteId),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invite ID copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copy Invite ID',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this ID with friends so they can invite you to teams!',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.privacy_tip, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Privacy Settings',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Discoverable in Search'),
              subtitle: Text(
                currentUser!.isPublic
                    ? 'Others can find you when searching for team members'
                    : 'You won\'t appear in user searches',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              value: currentUser!.isPublic,
              onChanged: (value) {
                _updatePrivacySetting('isPublic', value);
              },
            ),

            const Divider(),

            Text(
              'Profile Visibility',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Email'),
              subtitle: const Text('Allow others to see your email address'),
              value: currentUser!.profileVisibility.showEmail,
              onChanged: (value) {
                _updateProfileVisibility('showEmail', value);
              },
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Name'),
              subtitle: const Text('Allow others to see your full name'),
              value: currentUser!.profileVisibility.showName,
              onChanged: (value) {
                _updateProfileVisibility('showName', value);
              },
            ),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Bio'),
              subtitle: const Text('Allow others to see your bio/description'),
              value: currentUser!.profileVisibility.showBio,
              onChanged: (value) {
                _updateProfileVisibility('showBio', value);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updatePrivacySetting(String setting, dynamic value) async {
    try {
      User updatedUser;

      if (setting == 'isPublic') {
        updatedUser = await _userService!.updatePrivacySettings(
          isPublic: value,
          profileVisibility: currentUser!.profileVisibility.toJson(),
        );
      } else {
        return;
      }

      if (mounted) {
        setState(() {
          currentUser = updatedUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings updated!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error updating privacy settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $e')),
        );
      }
    }
  }

  void _updateProfileVisibility(String setting, bool value) async {
    try {
      final newVisibility = {
        'showEmail': setting == 'showEmail'
            ? value
            : currentUser!.profileVisibility.showEmail,
        'showName': setting == 'showName'
            ? value
            : currentUser!.profileVisibility.showName,
        'showBio': setting == 'showBio'
            ? value
            : currentUser!.profileVisibility.showBio,
      };

      final updatedUser = await _userService!.updatePrivacySettings(
        isPublic: currentUser!.isPublic,
        profileVisibility: newVisibility,
      );

      if (mounted) {
        setState(() {
          currentUser = updatedUser;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visibility settings updated!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _logger.e('Error updating visibility settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update settings: $e')),
        );
      }
    }
  }
}
