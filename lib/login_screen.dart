// lib/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'route_transitions.dart';
import 'root_nav_shell.dart';

// [CONFIG] acesso aos params (ex.: passwordMinLength)
import 'config/app_config.dart';

// [API] cliente HTTP centralizado
import 'services/api_client.dart';

// ====== Paleta / estilos base (alinhada às outras telas) ======
const _brand       = Color(0xFF143C8D); // azul da marca
const _cardBg      = Color(0xFFEFF6F9);
const _cardBorder  = Color(0xFFE2ECF2);
const _panelBg     = Color(0xFFF4F5F7);
const _panelBorder = Color(0xFFE5E8EE);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const String _prefsKeyCpf   = 'saved_cpf';
  static const String _prefsAuth     = 'auth_token';   // <— onde salvo o token retornado
  static const String _prefsLoggedIn = 'is_logged_in'; // <— flag simples de sessão
  static const String _firstAccessUrl =
      'https://assistweb.ipasemnh.com.br/site/recuperar-senha';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _cpfCtrl  = TextEditingController();
  final _pwdCtrl  = TextEditingController();
  final _cpfFocus = FocusNode();
  final _pwdFocus = FocusNode();

  bool _rememberCpf = true;
  bool _obscure     = true;
  bool _loading     = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCpf();
  }

  Future<void> _loadSavedCpf() async {
    final prefs  = await SharedPreferences.getInstance();
    final saved  = prefs.getString(LoginScreen._prefsKeyCpf) ?? '';
    if (saved.isNotEmpty) {
      _cpfCtrl.text   = saved;
      _rememberCpf    = true;
      setState(() {});
    }
  }

  String? _validateCpf(String? v) {
    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Informe seu CPF';
    if (digits.length != 11) return 'CPF deve ter 11 dígitos';
    return null;
  }

  String? _validatePwd(String? v) {
    // usa minLength dos params (com fallback 4 se algo der errado)
    final minLen = AppConfig.maybeOf(context)?.params.passwordMinLength ?? 4;
    final value = v ?? '';
    if (value.isEmpty) return 'Informe sua senha';
    if (value.length < minLen) return 'Senha muito curta (mínimo: $minLen)';
    return null;
  }

  Future<void> _submit() async {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    setState(() => _loading = true);
    try {
      // Normaliza CPF
      final digits = _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');
      final senha  = _pwdCtrl.text;

      // Salva/limpa CPF conforme opção
      final prefs = await SharedPreferences.getInstance();
      if (_rememberCpf) {
        await prefs.setString(LoginScreen._prefsKeyCpf, digits);
      } else {
        await prefs.remove(LoginScreen._prefsKeyCpf);
      }

      // ===== Chamada real de autenticação =====
      final api = ApiClient.of(context);
      final base = AppConfig.of(context).params.baseApiUrl;
      debugPrint('[API] baseApiUrl = $base');
      // Backend pode aceitar apenas CPF; enviamos ambos: backend ignora se não usar senha.
      final resp = await api.login(cpf: digits, senha: senha);

      final data = (resp.data is Map) ? (resp.data as Map) : {};
      if (data['ok'] != true) {
        final msg = (data['message'] ?? 'Falha ao autenticar').toString();
        throw Exception(msg);
      }

      // Token retornado (ajuste se for access_token/refresh_token)
      final token = (data['token'] ??
          data['access_token'] ??
          data['session'] ??
          '') as String;

      // Salva token/flag simples (considere flutter_secure_storage depois)
      if (token.isNotEmpty) {
        await prefs.setString(LoginScreen._prefsAuth, token);
      }
      await prefs.setBool(LoginScreen._prefsLoggedIn, true);

      // Fecha teclado e sincroniza frame
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 16));

      // Navega limpando a pilha
      await pushAndRemoveAllSharedAxis(
        context,
        const RootNavShell(),
        type: SharedAxisTransitionType.vertical,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha no login: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    if (!mounted) return;

    // Limpa qualquer resquício de sessão
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(LoginScreen._prefsAuth);
    await prefs.setBool(LoginScreen._prefsLoggedIn, false);

    FocusScope.of(context).unfocus();
    await Future.delayed(const Duration(milliseconds: 16));

    await pushAndRemoveAllSharedAxis(
      context,
      const RootNavShell(),
      type: SharedAxisTransitionType.vertical,
    );
  }

  Future<void> _openFirstAccess() async {
    final uri = Uri.parse(LoginScreen._firstAccessUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) throw Exception('Não foi possível abrir o endereço.');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }

  @override
  void dispose() {
    _cpfCtrl.dispose();
    _pwdCtrl.dispose();
    _cpfFocus.dispose();
    _pwdFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth > 560 ? 560 : double.infinity,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                const _LogoBanner(),
                const SizedBox(height: 16),

                // Bloco do formulário
                Container(
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cardBorder, width: 2),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // CPF
                        TextFormField(
                          controller: _cpfCtrl,
                          focusNode: _cpfFocus,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          decoration: InputDecoration(
                            labelText: 'CPF',
                            hintText: '00000000000',
                            filled: true,
                            fillColor: Colors.white, // fundo branco
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _brand, width: 1.6),
                            ),
                          ),
                          validator: _validateCpf,
                          onFieldSubmitted: (_) => _pwdFocus.requestFocus(),
                        ),
                        const SizedBox(height: 12),

                        // Senha
                        TextFormField(
                          controller: _pwdCtrl,
                          focusNode: _pwdFocus,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            filled: true,
                            fillColor: Colors.white, // fundo branco
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _brand, width: 1.6),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                            ),
                          ),
                          validator: _validatePwd,
                          onFieldSubmitted: (_) => _submit(),
                        ),

                        const SizedBox(height: 8),

                        // Lembrar CPF + link Primeiro Acesso?
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberCpf,
                              onChanged: (v) => setState(() => _rememberCpf = v ?? true),
                            ),
                            const Text('Lembrar CPF'),
                            const Spacer(),
                            TextButton(
                              onPressed: _openFirstAccess,
                              child: const Text('Primeiro Acesso?'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Botão Logar
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _brand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                                : const Text(
                              'Logar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Botão Visitante
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: _brand, width: 1.5),
                              foregroundColor: _brand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _loading ? null : _continueAsGuest,
                            child: const Text(
                              'Entrar como Visitante',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Aviso / dicas
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _panelBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _panelBorder),
                  ),
                  child: const Text(
                    'Use seu CPF e senha cadastrados. Caso seja seu primeiro acesso, '
                        'clique em “Primeiro Acesso?” para criar/recuperar sua senha.',
                    style: TextStyle(color: Color(0xFF475467)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Banner reutilizado para manter identidade visual
class _LogoBanner extends StatelessWidget {
  const _LogoBanner();

  static const double _h = 110;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: _cardBg,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/icons/logo_ipasem.png',
            height: _h * 0.55,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
