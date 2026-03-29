import 'package:flutter/material.dart';

Future<void> showSuccess(
  BuildContext context,
  String message, {
  String title = 'Success',
  Duration autoCloseAfter = const Duration(milliseconds: 1400),
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (autoCloseAfter > Duration.zero) {
    Future.delayed(autoCloseAfter, () {
      if (navigator.canPop()) {
        navigator.pop();
      }
    });
  }

  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'success',
    pageBuilder: (context, animation, secondaryAnimation) =>
        const SizedBox.shrink(),
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return Transform.scale(
        scale: curved.value,
        child: Opacity(
          opacity: animation.value,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
          ),
        ),
      );
    },
  );
}
