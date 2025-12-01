import 'package:flutter/material.dart';

class ResumoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ResumoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF667085)),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF101828),
        ),
      ),
      trailing: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF101828),
        ),
      ),
      minLeadingWidth: 0,
    );
  }
}
