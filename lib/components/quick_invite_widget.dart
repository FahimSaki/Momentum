import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:momentum/services/user_service.dart';
import 'package:provider/provider.dart';

class QuickInviteWidget extends StatefulWidget {
  const QuickInviteWidget({super.key});

  @override
  State createState() => _QuickInviteWidgetState();
}

class _QuickInviteWidgetState extends State {
  String? userInviteId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInviteId();
  }

  void _loadUserInviteId() async {
    final db = Provider.of(context, listen: false);
    final userService = UserService(jwtToken: db.jwtToken ?? '');

    try {
      final user = await userService.getCurrentUserProfile();
      if (mounted) {
        setState(() {
          userInviteId = user.inviteId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.withValues(alpha: 0.1),
            Colors.purple.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tag, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Invite ID',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        userInviteId ?? 'Loading...',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: userInviteId != null
                      ? () {
                          Clipboard.setData(ClipboardData(text: userInviteId!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('📋 Invite ID copied!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy Invite ID',
                ),
              ],
            ),
    );
  }
}


// This Widget doesn't have all the function calls