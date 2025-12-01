// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ipasemnhdigital/frontend/views/screens/privacidade_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../backend/controller/login_controller.dart';
import '../../../common/config/app_config.dart';
import '../../../backend/config/validators.dart';
import '../../../common/data/consent_store.dart';
import '../../../common/repositories/auth_repository.dart';
import '../../../common/config/api_router.dart';
import '../components/consent_dialog.dart';
import '../layouts/root_nav_shell.dart';
import '../../../route_transitions.dart';
import '../../theme/colors.dart';
import 'termos_screen.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const bool _visitorTemporarilyDisabled = true;

  final _formKey = GlobalKey<FormState>();
  final _cpfCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _cpfF = FocusNode();
  final _pwdF = FocusNode();

  late LoginController _c;
  bool _controllerReady = false;

  // Evita navegação duplicada (toques repetidos).
  bool _navigatingToApp = false;

  // Controle de visibilidade da senha
  bool _obscurePwd = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllerReady) return;

    // Cliente HTTP via ApiRouter
    final repo = AuthRepository(ApiRouter.client());
    _c = LoginController(repo: repo, appConfig: AppConfig.maybeOf(context));
    _controllerReady = true;

    // Restaura prefs (NÃO navega)
    _restoreFromController();
  }

  Future<void> _restoreFromController() async {
    await _c.init();
    if (!mounted) return;
    if (_c.savedCpf.isNotEmpty) _cpfCtrl.text = _c.savedCpf;
    if (_c.savedPassword.isNotEmpty) _pwdCtrl.text = _c.savedPassword;
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
    if (_navigatingToApp) return;
    _navigatingToApp = true;
    FocusScope.of(context).unfocus();

    // Remove TODAS as rotas e abre a RootNavShell "única".
    await pushAndRemoveAllSharedAxis(
      context,
      const RootNavShell(),
      type: SharedAxisTransitionType.vertical,
    );

    _navigatingToApp = false;
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

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Garante aceite dos Termos/Privacidade ANTES do login.
  Future<bool> _ensureTermsForLogin() async {
    if (await ConsentStore.isAccepted()) return true;

    final accepted = await ConsentDialog.show(
      context,
      onOpenPrivacy: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PrivacidadeScreen(minimal: true)),
      ),
      onOpenTerms: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TermosScreen(minimal: true)),
      ),
    );

    if (accepted == true) {
      await ConsentStore.setAccepted(true);
      return true;
    }
    _snack('É necessário aceitar os termos para continuar.');
    return false;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Termos no ato do login
    if (!await _ensureTermsForLogin()) return;

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
    // Temporariamente desabilitado para evitar empilhamento de shells/sessões.
    _snack('Acesso como visitante temporariamente desabilitado.');
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
                              obscureText: _obscurePwd,
                              decoration: _deco(
                                'Senha',
                                suffix: _PasswordRevealSuffix(
                                  obscured: _obscurePwd,
                                  onToggle: () => setState(() => _obscurePwd = !_obscurePwd),
                                  onPressAndHoldStart: () => setState(() => _obscurePwd = false),
                                  onPressAndHoldEnd: () => setState(() => _obscurePwd = true),
                                ),
                              ),
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
                                          if (mounted) setState(() {});
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

                              // Direita: link compacto
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

                        // ===== AVISO: Wi-Fi do IPASEM desconectado (acima do botão Logar)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFFFFF7E6), // tom âmbar suave
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFFFFE2A1)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.wifi_off, color: Color(0xFF8A6100)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Wi-Fi do IPASEM deve estar DESCONECTADO',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF8A6100),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Use 4G/5G ou outra rede Wi-Fi. A rede interna do IPASEM impede o acesso às rotinas do app.',
                                      style: TextStyle(color: Color(0xFF8A6100)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        // ===== Botões
                        ValueListenableBuilder<bool>(
                          valueListenable: _c.loading,
                          builder: (_, busy, __) => Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 48,
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

                              // Visitante temporariamente desabilitado
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: kBrand, width: 1.5),
                                    foregroundColor: kBrand,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: (busy || _visitorTemporarilyDisabled) ? null : _continueAsGuest,
                                  child: const Text(
                                    'Entrar como Visitante',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                              if (_visitorTemporarilyDisabled) ...[
                                const SizedBox(height: 8),
                                const Text(
                                  'Acesso como visitante desabilitado temporariamente para correção de estabilidade.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Color(0xFF475467)),
                                ),
                              ],
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
                        'clique em “Primeiro Acesso?” para criar/recuperar sua senha. '
                        'Ao prosseguir com o login, você deverá aceitar os Termos de Uso e a Política de Privacidade.',
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

class _PasswordRevealSuffix extends StatelessWidget {
  const _PasswordRevealSuffix({
    required this.obscured,
    required this.onToggle,
    required this.onPressAndHoldStart,
    required this.onPressAndHoldEnd,
  });

  final bool obscured;
  final VoidCallback onToggle;
  final VoidCallback onPressAndHoldStart;
  final VoidCallback onPressAndHoldEnd;

  @override
  Widget build(BuildContext context) {
    // Ícone + suporte a press-and-hold para visualizar temporariamente
    return GestureDetector(
      onLongPress: onPressAndHoldStart,
      onLongPressUp: onPressAndHoldEnd,
      child: IconButton(
        onPressed: onToggle,
        tooltip: obscured ? 'Mostrar senha' : 'Ocultar senha',
        icon: Icon(obscured ? Icons.visibility_off : Icons.visibility),
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
