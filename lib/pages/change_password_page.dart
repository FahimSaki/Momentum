import 'package:flutter/material.dart';
import 'package:momentum/components/responsive_layout.dart';
import 'package:momentum/database/task_database.dart';
import 'package:momentum/services/user_service.dart';
import 'package:provider/provider.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSendingCode = false;
  String? _error;

  UserService? _userService;

  @override
  void initState() {
    super.initState();
    final db = Provider.of<TaskDatabase>(context, listen: false);
    if (db.jwtToken != null) {
      _userService = UserService(jwtToken: db.jwtToken!);
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      setState(() => _error = 'Enter your current password');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    if (_userService == null) {
      setState(() => _error = 'Not signed in — please restart the app');
      return;
    }

    setState(() {
      _isSendingCode = true;
      _error = null;
    });

    try {
      await _userService!.requestPasswordChange(currentPassword);
      if (!mounted) return;

      final changed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PasswordChangeVerificationDialog(
          userService: _userService!,
          newPassword: newPassword,
          onResend: () => _userService!.requestPasswordChange(currentPassword),
        ),
      );

      if (changed == true && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSendingCode = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: ResponsiveCenter(
        maxWidth: AppWidths.authForm,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF6366F1)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "For your security, we'll email you a code to confirm this change.",
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(
                          context,
                        ).colorScheme.inversePrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _currentPasswordController,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                border: UnderlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              obscureText: true,
              enabled: !_isSendingCode,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(
                labelText: 'New Password',
                border: UnderlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                helperText: 'At least 6 characters',
              ),
              obscureText: true,
              enabled: !_isSendingCode,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                border: UnderlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
              enabled: !_isSendingCode,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSendingCode ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSendingCode
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Send Verification Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── OTP confirmation dialog ────────────────────────────────────────────────

class _PasswordChangeVerificationDialog extends StatefulWidget {
  final UserService userService;
  final String newPassword;
  final Future<void> Function() onResend;

  const _PasswordChangeVerificationDialog({
    required this.userService,
    required this.newPassword,
    required this.onResend,
  });

  @override
  State<_PasswordChangeVerificationDialog> createState() =>
      _PasswordChangeVerificationDialogState();
}

class _PasswordChangeVerificationDialogState
    extends State<_PasswordChangeVerificationDialog> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email');
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.userService.confirmPasswordChange(
        code: code,
        newPassword: widget.newPassword,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _error = null;
      _info = null;
    });
    try {
      await widget.onResend();
      if (mounted) setState(() => _info = 'A new code has been sent.');
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.mark_email_read_rounded, color: Color(0xFF6366F1)),
          SizedBox(width: 10),
          Text('Confirm Change'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the 6-digit code sent to your email to confirm your new password.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              letterSpacing: 10,
            ),
            decoration: const InputDecoration(
              hintText: '000000',
              counterText: '',
            ),
            enabled: !_isVerifying,
            onChanged: (_) => setState(() {
              _error = null;
              _info = null;
            }),
            onSubmitted: (_) => _verify(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ],
          if (_info != null) ...[
            const SizedBox(height: 8),
            Text(
              _info!,
              style: const TextStyle(color: Colors.green, fontSize: 13),
            ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _isResending ? null : _resend,
              child: _isResending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Resend code'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isVerifying ? null : _verify,
          child: _isVerifying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}
