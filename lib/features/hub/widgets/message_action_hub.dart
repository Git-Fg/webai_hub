import 'package:ai_hybrid_hub/shared/ui_constants.dart';
import 'package:flutter/material.dart';

class MessageActionHub extends StatelessWidget {
  const MessageActionHub({
    required this.onCopy,
    required this.onEdit,
    this.onResend,
    super.key,
  });

  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(kDefaultBorderRadius),
      child: SizedBox(
        width: 150,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48, // WHY: Enforce 48px minimum height for accessibility.
              child: ListTile(
                leading: const Icon(Icons.copy, size: kDefaultIconSize),
                title: const Text('Copy'),
                onTap: onCopy,
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 48, // WHY: Enforce 48px minimum height for accessibility.
              child: ListTile(
                leading: const Icon(Icons.edit, size: kDefaultIconSize),
                title: const Text('Edit'),
                onTap: onEdit,
              ),
            ),
            if (onResend != null) ...[
              const Divider(height: 1),
              SizedBox(
                height:
                    48, // WHY: Enforce 48px minimum height for accessibility.
                child: ListTile(
                  leading: const Icon(
                    Icons.send_and_archive,
                    size: kDefaultIconSize,
                  ),
                  title: const Text('Resend'),
                  onTap: onResend,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
