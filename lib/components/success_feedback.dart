// lib/components/success_feedback.dart - NEW FILE

import 'package:flutter/material.dart';

class SuccessFeedback {
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    IconData icon = Icons.check_circle,
    Color color = Colors.green,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  static void showTaskCreated(
    BuildContext context,
    String taskName, {
    bool isTeamTask = false,
  }) {
    showSuccess(
      context,
      isTeamTask
          ? 'Team task "$taskName" created and assigned!'
          : 'Personal task "$taskName" created!',
      title: 'Success!',
      icon: Icons.task_alt,
    );
  }

  static void showTeamCreated(BuildContext context, String teamName) {
    showSuccess(
      context,
      'Team "$teamName" created successfully!',
      title: 'Welcome to your new team!',
      icon: Icons.group,
    );
  }

  static void showInvitationSent(BuildContext context, String email) {
    showSuccess(
      context,
      'Invitation sent to $email',
      title: 'Invitation Sent',
      icon: Icons.mail_outline,
    );
  }

  static void showTaskCompleted(BuildContext context, String taskName) {
    showSuccess(
      context,
      '"$taskName" completed! Great job! 🎉',
      icon: Icons.celebration,
    );
  }
}
