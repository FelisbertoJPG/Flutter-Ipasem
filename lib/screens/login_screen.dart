import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../core/validators.dart';
import '../repositories/auth_repository.dart';
import '../services/dev_api.dart';
import '../theme/colors.dart';
import '../route_transitions.dart';
import '../root_nav_shell.dart';
import '../ui/components/consent_dialog.dart';
import 'privacidade_screen.dart';
import 'termos_screen.dart';

import '../controllers/login_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cpfCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _cpfF = FocusNode();
  final _pwdF = FocusNode();

  late LoginController _c;
  bool _controllerReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllerReady) return;

    final baseUrl = AppConfig.maybeOf(context)?.params.baseApiUrl
        ?? const String.fromEnvironment('API_BASE', defaultValue: 'http://192.9.200.98');

    final repo = AuthRepository(DevApi(baseUrl));
    _c = LoginController(repo: repo, appConfig: AppConfig.maybeOf(context));
    _controllerReady = true;

    // restaura prefs (NÃO navega)
    _restoreFromController();
  }

  Future<void> _restoreFromController() async {
    await _c.init();
    if (!mounted) return;
    if (_c.savedCpf.isNotEmpty) _cpfCtrl.text = _c.savedCpf;
    if (_c.savedPassword.isNotEmpty) _pwdCtrl.text = _c.savedPassword; // aqui!
    setState(() {});
  }


  @override
  void dispose() {
    _c.dispose();
    _cpfCtrl.dispose();
    _pwdCtrl.dispose();
    _cpfF.dispose();
    _pwdF.dispose();
    super.dispose();
  }

  Future<void> _goToApp() async {
    FocusScope.of(context).unfocus();
    await pushAndRemoveAllSharedAxis(
      context,
      const RootNavShell(),
      type: SharedAxisTransitionType.vertical,
    );
  }

  InputDecoration _deco(String label, {String? hint, Widget? suffix}) => InputDecoration(
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

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final (outcome, message) = await _c.submit(
      rawCpfDigits: _cpfCtrl.text.replaceAll(RegExp(r'\D'), ''),
      password: _pwdCtrl.text,
    );
    if (!mounted) return;
    switch (outcome) {
      case LoginOutcome.success:
        await _goToApp();
        break;
      case LoginOutcome.error:
        _snack(message ?? 'Falha no login');
        break;
      default:
        break;
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

    final (outcome, _) = await _c.continueAsGuest();
    if (outcome == LoginOutcome.guest && mounted) await _goToApp();
  }

  Future<void> _openFirstAccess() async {
    try {
      final ok = await launchUrl(
        Uri.parse(_c.firstAccessUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception();
    } catch (_) {
      _snack('Não foi possível abrir o link.');
    }
  }

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

                // ===== Card do formulário
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
                          validator: validateCpfDigits,
                          onFieldSubmitted: (_) => _pwdF.requestFocus(),
                        ),
                        const SizedBox(height: 12),
                        ValueListenableBuilder(
                          valueListenable: _c.loading,
                          builder: (_, __, ___) {
                            return TextFormField(
                              controller: _pwdCtrl,
                              focusNode: _pwdF,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              obscureText: true,
                              decoration: _deco('Senha'),
                              validator: (v) => validatePassword(
                                v,
                                minLen: AppConfig.maybeOf(context)?.params.passwordMinLength ?? 4,
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              enabled: !_c.loading.value,
                            );
                          },
                        ),
                        const SizedBox(height: 8),


                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              // Esquerda: checkbox + rótulo com flex
                              Expanded(
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    ValueListenableBuilder<bool>(
                                      valueListenable: _c.staySignedIn,
                                      builder: (_, val, __) => Checkbox(
                                        value: val,
                                        onChanged: (v) async {
                                          final b = v ?? false;
                                          await _c.setStaySignedIn(b); // salva staySignedIn e limpa senha se desmarcar
                                          await _c.setRememberCpf(b);  // sincroniza CPF
                                          setState(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Flexible(
                                      child: Text(
                                        'Manter login',
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Direita: link compacto que não força overflow
                              Flexible(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _openFirstAccess,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: const Size(0, 36),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: const Text(
                                      'Primeiro Acesso?',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),


                        const SizedBox(height: 8),

                        // ===== Botões
                        ValueListenableBuilder<bool>(
                          valueListenable: _c.loading,
                          builder: (_, busy, __) => Column(
                            children: [
                              SizedBox(
                                width: double.infinity, height: 48,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kBrand,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: busy ? null : _submit,
                                  child: busy
                                      ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                      : const Text('Logar',
                                      style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity, height: 48,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: kBrand, width: 1.5),
                                    foregroundColor: kBrand,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: busy ? null : _continueAsGuest,
                                  child: const Text(
                                    'Entrar como Visitante',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
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
