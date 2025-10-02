// lib/screens/login_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/formatters.dart';
import '../services/dev_api.dart';
import '../services/session.dart';
import '../theme/colors.dart';
import '../route_transitions.dart';
import '../root_nav_shell.dart';
import '../config/app_config.dart';

import '../repositories/auth_repository.dart';
import '../models/profile.dart';

import 'privacidade_screen.dart';
import 'termos_screen.dart';
import '../ui/components/consent_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static const _prefsKeyCpf   = 'saved_cpf';
  static const _prefsAuth     = 'auth_token';
  static const _prefsLoggedIn = 'is_logged_in';
  static const _firstAccessUrl =
      'https://assistweb.ipasemnh.com.br/site/recuperar-senha';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _cpfCtrl  = TextEditingController();
  final _pwdCtrl  = TextEditingController();
  final _cpfFocus = FocusNode();
  final _pwdFocus = FocusNode();

  bool _rememberCpf = true;
  bool _obscure = true;
  bool _loading = false;

  late AuthRepository _repo;
  bool _repoReady = false; // garante init único

  @override
  void initState() {
    super.initState();
    _loadSavedCpf();
  }

  // AppConfig/of(context) só aqui (ou no build)
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_repoReady) {
      final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
          ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');
      debugPrint('>>> API BASE = $baseUrl');
      _repo = AuthRepository(DevApi(baseUrl));
      _repoReady = true;
    }
  }

  Future<void> _loadSavedCpf() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(LoginScreen._prefsKeyCpf) ?? '';
    if (saved.isNotEmpty) {
      _cpfCtrl.text = saved;
      _rememberCpf = true;
      if (mounted) setState(() {});
    }
  }

  String? _validateCpf(String? v) {
    final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return 'Informe seu CPF';
    if (d.length != 11) return 'CPF deve ter 11 dígitos';
    return null;
  }

  String? _validatePwd(String? v) {
    final min = AppConfig.maybeOf(context)?.params.passwordMinLength ?? 4;
    if ((v ?? '').isEmpty) return 'Informe sua senha';
    if ((v ?? '').length < min) return 'Senha muito curta (mínimo: $min)';
    return null;
  }

  InputDecoration _fieldDeco({required String label, String? hint, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBrand, width: 1.6),
      ),
      suffixIcon: suffix,
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_repoReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Serviço de login ainda inicializando.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final raw = _cpfCtrl.text;
      final cpfDigits = raw.replaceAll(RegExp(r'\D'), ''); // só dígitos (pra validar/salvar)
      final cpfToSend = fmtCpf(cpfDigits);                 // formatado XXX.XXX.XXX-XX (pra API)
      final senha = _pwdCtrl.text;

      final prefs = await SharedPreferences.getInstance();
      if (_rememberCpf) {
        await prefs.setString(LoginScreen._prefsKeyCpf, cpfDigits); // salva só dígitos
      } else {
        await prefs.remove(LoginScreen._prefsKeyCpf);
      }

      // === LOGIN via API DEV (envia formatado) ===
      final Profile profile = await _repo.login(cpfToSend, senha);

      // Salva sessão/persistência centralizada
      await Session.saveLogin(profile, token: 'dev');

      if (!mounted) return;
      FocusScope.of(context).unfocus();
      await pushAndRemoveAllSharedAxis(
        context,
        const RootNavShell(),
        type: SharedAxisTransitionType.vertical,
      );
    } on DioException catch (e) {
      String msg = 'Falha no login';
      final data = e.response?.data;
      if (data is Map && data['error'] is Map && data['error']['message'] is String) {
        msg = data['error']['message'] as String; // ex.: "CPF ou senha inválidos."
      } else if (e.message != null && e.message!.isNotEmpty) {
        msg = e.message!;
      }
      debugPrint('DioException: ${e.type}  status=${e.response?.statusCode} body=${e.response?.data}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e, st) {
      debugPrint('Login error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Falha no login')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    final accepted = await ConsentDialog.show(
      context,
      onOpenPrivacy: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const PrivacidadeScreen(minimal: true),
          fullscreenDialog: true,
        ));
      },
      onOpenTerms: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const TermosScreen(minimal: true),
          fullscreenDialog: true,
        ));
      },
    );
    if (accepted != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(LoginScreen._prefsAuth);
    await prefs.setBool(LoginScreen._prefsLoggedIn, false);
    await prefs.setBool('visitor_consent_accepted', true);

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await pushAndRemoveAllSharedAxis(
      context,
      const RootNavShell(),
      type: SharedAxisTransitionType.vertical,
    );
  }

  Future<void> _openFirstAccess() async {
    try {
      final ok = await launchUrl(
        Uri.parse(LoginScreen._firstAccessUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception();
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
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width > 560 ? 560 : double.infinity),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              children: [
                const _LogoBanner(),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kCardBorder, width: 2),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
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
                          decoration: _fieldDeco(label: 'CPF', hint: '00000000000'),
                          validator: _validateCpf,
                          onFieldSubmitted: (_) => _pwdFocus.requestFocus(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pwdCtrl,
                          focusNode: _pwdFocus,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          obscureText: _obscure,
                          decoration: _fieldDeco(
                            label: 'Senha',
                            suffix: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              ),
                              tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                            ),
                          ),
                          validator: _validatePwd,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberCpf,
                              onChanged: (v) => setState(() => _rememberCpf = (v ?? true)),
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
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: kBrand,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                : const Text('Logar', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kBrand, width: 1.5),
                              foregroundColor: kBrand,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kPanelBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPanelBorder),
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
          color: kCardBg,
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
