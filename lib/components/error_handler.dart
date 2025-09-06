import 'package:flutter/material.dart';

class ErrorHandler {
  static void showError(BuildContext context, dynamic error, {String? title}) {
    final errorMessage = _extractErrorMessage(error);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildErrorSuggestions(errorMessage),
          ],
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

  static void showSnackBarError(BuildContext context, dynamic error) {
    final errorMessage = _extractErrorMessage(error);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(errorMessage)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _extractErrorMessage(dynamic error) {
    String message = error.toString();

    // Remove "Exception: " prefix
    if (message.startsWith('Exception: ')) {
      message = message.substring(11);
    }

    // Handle specific error types
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('network') || lowerMessage.contains('socket')) {
      return 'Network connection error. Please check your internet.';
    } else if (lowerMessage.contains('timeout')) {
      return 'Request timed out. Please try again.';
    } else if (lowerMessage.contains('401') ||
        lowerMessage.contains('unauthorized')) {
      return 'Your session has expired. Please login again.';
    } else if (lowerMessage.contains('403') ||
        lowerMessage.contains('forbidden')) {
      return 'You don\'t have permission to perform this action.';
    } else if (lowerMessage.contains('404') ||
        lowerMessage.contains('not found')) {
      return 'The requested resource was not found.';
    } else if (lowerMessage.contains('500') ||
        lowerMessage.contains('server error')) {
      return 'Server error. Please try again later.';
    }

    return message;
  }

  static Widget _buildErrorSuggestions(String errorMessage) {
    List<Widget> suggestions = [];

    if (errorMessage.toLowerCase().contains('network')) {
      suggestions.addAll([
        const Text(
          '💡 Try these solutions:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('• Check your internet connection'),
        const Text('• Try switching between WiFi and mobile data'),
        const Text('• Wait a moment and try again'),
      ]);
    } else if (errorMessage.toLowerCase().contains('session') ||
        errorMessage.toLowerCase().contains('unauthorized')) {
      suggestions.addAll([
        const Text(
          '🔐 Authentication Issue:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('• Your session has expired'),
        const Text('• Please login again to continue'),
      ]);
    } else if (errorMessage.toLowerCase().contains('permission')) {
      suggestions.addAll([
        const Text(
          '🚫 Permission Issue:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('• You may not have permission for this action'),
        const Text('• Check with your team administrator'),
      ]);
    } else {
      suggestions.addAll([
        const Text(
          '🔧 General troubleshooting:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('• Try restarting the app'),
        const Text('• Check if the issue persists'),
        const Text('• Contact support if problem continues'),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: suggestions,
      ),
    );
  }
}
