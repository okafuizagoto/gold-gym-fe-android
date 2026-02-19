import 'package:flutter/material.dart';

class ModalWrapper extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final bool scrollable;

  const ModalWrapper({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: width ?? MediaQuery.of(context).size.width * 0.9,
        height: height,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: scrollable
            ? SingleChildScrollView(child: child)
            : child,
      ),
    );
  }
}

// Helper function to show modal dialog
Future<T?> showModalDialog<T>({
  required BuildContext context,
  required Widget child,
  double? width,
  double? height,
  bool scrollable = false,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: ModalWrapper(
        width: width,
        height: height,
        scrollable: scrollable,
        child: child,
      ),
    ),
  );
}
