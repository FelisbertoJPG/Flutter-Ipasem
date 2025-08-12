// lib/login.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const Color _brandBlue = Color(0xFF143C8D);
  static const Color _accentPurple = Color(0xFF6A37B8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo topo-esquerda
                Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/images/icons/splash_logo.png', // icone png
                    height: 44,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),

                // Label "Insira seu CPF"
                Text(
                  'Insira seu CPF',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ).copyWith(color: _brandBlue),
                ),
                const SizedBox(height: 8),

                // Campo CPF
                TextField(
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    hintText: '000.000.000-00',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _brandBlue, width: 2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: _brandBlue, width: 2.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Botão Entrar
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: lógica do login
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandBlue,
                      shape: const StadiumBorder(),
                      elevation: 0,
                    ),
                    child: const Text(
                      'ENTRAR',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Link "Primeiro Acesso? Clique Aqui!!"
                Center(
                  child: TextButton(
                    onPressed: () {
                      // TODO: navegar para primeiro acesso
                    },
                    child: const Text(
                      'Primeiro Acesso? Clique Aqui!!',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ).copyWith(color: _accentPurple),
                  ),
                ),

                const SizedBox(height: 8),

                // "Duvidas ?"
                Center(
                  child: Text(
                    'Duvidas ?',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ).copyWith(color: _accentPurple),
                  ),
                ),
                const SizedBox(height: 12),

                // Cartões de ação
                Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.alternate_email_outlined,
                        label: 'Enviar E-mail',
                        iconColor: _brandBlue,
                        labelColor: _accentPurple,
                        onTap: () {
                          // TODO: ação de e-mail
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.add_call,
                        label: 'Ligar',
                        iconColor: _brandBlue,
                        labelColor: _accentPurple,
                        onTap: () {
                          // TODO: ação de telefonar
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color labelColor;
  final Color iconColor;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.labelColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

