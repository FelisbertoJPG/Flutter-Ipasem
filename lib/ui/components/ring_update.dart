import 'package:flutter/material.dart';

class RingUpdateBanner extends StatelessWidget {
  final int quantidade;
  final VoidCallback onTap;
  final Color? background;
  final IconData icon;

  const RingUpdateBanner({
    super.key,
    required this.quantidade,
    required this.onTap,
    this.background,
    this.icon = Icons.notifications_active_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final plural = quantidade > 1 ? 'autorizações' : 'autorização';
    return Card(
      color: background ?? Colors.amber.shade50,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        dense: true,
        leading: Icon(icon),
        title: Text(
          '$quantidade $plural mudou de situação',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        trailing: TextButton(onPressed: onTap, child: const Text('Ver')),
        onTap: onTap,
      ),
    );
  }
}
