// lib/screens/login_screen.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../core/formatters.dart';
import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import '../route_transitions.dart';
import '../root_nav_shell.dart';
import '../services/dev_api.dart';
import '../services/session.dart';
import '../theme/colors.dart';
import '../ui/components/consent_dialog.dart';
import 'privacidade_screen.dart';
import 'termos_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  // chaves de preferência (persistência leve)
  static const _kSavedCpf   = 'saved_cpf';
  static const _kAuthToken  = 'auth_token';
  static const _kIsLoggedIn = 'is_logged_in';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ---- state ----
  final _formKey  = GlobalKey<FormState>();
  final _cpfCtrl  = TextEditingController();
  final _pwdCtrl  = TextEditingController();
  final _cpfF     = FocusNode();
  final _pwdF     = FocusNode();

  bool _rememberCpf = true, _obscure = true, _loading = false;

  late final AuthRepository _repo; // inicializado em didChangeDependencies
  bool _repoReady = false;

  // ---- lifecycle ----
  @override
  void initState() {
    super.initState();
    _warmupPrefs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_repoReady) return;

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
        ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');

    _repo = AuthRepository(DevApi(baseUrl));
    _repoReady = true;
  }

  @override
  void dispose() {
    _cpfCtrl.dispose();
    _pwdCtrl.dispose();
    _cpfF.dispose();
    _pwdF.dispose();
    super.dispose();
  }

  // ---- helpers ----
  Future<void> _warmupPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(LoginScreen._kSavedCpf) ?? '';
    if (saved.isNotEmpty) {
      _cpfCtrl.text = saved;
      setState(() => _rememberCpf = true);
    }
  }

  String? _valCpf(String? v) {
    final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return 'Informe seu CPF';
    if (d.length != 11) return 'CPF deve ter 11 dígitos';
    return null;
  }

  String? _valPwd(String? v) {
    final min = AppConfig.maybeOf(context)?.params.passwordMinLength ?? 4;
    if ((v ?? '').isEmpty) return 'Informe sua senha';
    if ((v ?? '').length < min) return 'Senha muito curta (mínimo: $min)';
    return null;
  }

  InputDecoration _deco(String label, {String? hint, Widget? suffix}) => InputDecoration(
    labelText: label, hintText: hint, filled: true, fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kCardBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBrand, width: 1.6),
    ),
    suffixIcon: suffix,
  );

  // ---- actions ----
  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_repoReady) {
      _snack('Serviço de login ainda inicializando.');
      return;
    }

    setState(() => _loading = true);
    try {
      final digits   = _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');
      final cpfFmt   = fmtCpf(digits);     // envia formatado (XXX.XXX.XXX-XX)
      final senha    = _pwdCtrl.text;
      final prefs    = await SharedPreferences.getInstance();

      // lembrar cpf (apenas dígitos)
      _rememberCpf
          ? await prefs.setString(LoginScreen._kSavedCpf, digits)
          : await prefs.remove(LoginScreen._kSavedCpf);

      // chama API (via repo)
      final Profile profile = await _repo.login(cpfFmt, senha);

      // salva sessão centralizada
      await Session.saveLogin(profile, token: 'dev');

      if (!mounted) return;
      FocusScope.of(context).unfocus();
      await pushAndRemoveAllSharedAxis(
        context, const RootNavShell(), type: SharedAxisTransitionType.vertical,
      );
    } on DioException catch (e) {
      // mensagem amigável do backend (se existir)
      String msg = 'Falha no login';
      final data = e.response?.data;
      if (data is Map && data['error'] is Map && data['error']['message'] is String) {
        msg = data['error']['message'] as String;
      } else if ((e.message ?? '').isNotEmpty) {
        msg = e.message!;
      }
      _snack(msg);
    } catch (_) {
      _snack('Falha no login');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    final ok = await ConsentDialog.show(
      context,
      onOpenPrivacy: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PrivacidadeScreen(minimal: true)),
      ),
      onOpenTerms: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TermosScreen(minimal: true)),
      ),
    );
    if (ok != true) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(LoginScreen._kAuthToken);
    await prefs.setBool(LoginScreen._kIsLoggedIn, false);
    await prefs.setBool('visitor_consent_accepted', true);

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await pushAndRemoveAllSharedAxis(
      context, const RootNavShell(), type: SharedAxisTransitionType.vertical,
    );
  }

  Future<void> _openFirstAccess() async {
    final url = AppConfig.maybeOf(context)?.params.firstAccessUrl
        ?? 'https://assistweb.ipasemnh.com.br/site/recuperar-senha';
    try {
      if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        throw Exception();
      }
    } catch (_) {
      _snack('Não foi possível abrir o link.');
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width > 560 ? 560.0 : double.infinity;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
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
                          focusNode: _cpfF,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11),
                          ],
                          decoration: _deco('CPF', hint: '00000000000'),
                          validator: _valCpf,
                          onFieldSubmitted: (_) => _pwdF.requestFocus(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _pwdCtrl,
                          focusNode: _pwdF,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          obscureText: _obscure,
                          decoration: _deco(
                            'Senha',
                            suffix: IconButton(
                              tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                              icon: Icon(_obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: _valPwd,
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberCpf,
                              onChanged: (v) => setState(() => _rememberCpf = v ?? true),
                            ),
                            const Text('Lembrar CPF'),
                            const Spacer(),
                            TextButton(onPressed: _openFirstAccess, child: const Text('Primeiro Acesso?')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity, height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: kBrand,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white)),
                            )
                                : const Text('Logar', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity, height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kBrand, width: 1.5),
                              foregroundColor: kBrand,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _loading ? null : _continueAsGuest,
                            child: const Text('Entrar como Visitante', style: TextStyle(fontWeight: FontWeight.w700)),
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
                    color: kPanelBg, borderRadius: BorderRadius.circular(12),
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
            height: _h * 0.55, fit: BoxFit.contain, filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }
}
