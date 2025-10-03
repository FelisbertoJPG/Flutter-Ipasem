import 'package:flutter/material.dart';
import '../../theme/colors.dart';

class LockedNotice extends StatelessWidget {
  final String message;

  const LockedNotice({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPanelBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPanelBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFF667085)),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFF475467)))),
        ],
      ),
    );
  }
}
