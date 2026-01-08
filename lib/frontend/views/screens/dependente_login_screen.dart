// lib/frontend/views/screens/dependente_login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ipasemnhdigital/frontend/views/screens/privacidade_screen.dart';
import 'package:ipasemnhdigital/frontend/views/screens/termos_screen.dart';

import '../../../../../backend/config/validators.dart';
import '../../../../../backend/controller/login_dependente_controller.dart';
import '../../../../../common/config/api_router.dart';
import '../../../../../common/config/app_config.dart';
import '../../../../../common/data/consent_store.dart';
import '../../../../../common/repositories/auth_repository.dart';
import '../../../../../route_transitions.dart';
import '../../theme/colors.dart';
import '../components/consent_dialog.dart';
import '../layouts/root_nav_shell.dart';
import 'dependente_vinculo_screen.dart';

class DependenteLoginScreen extends StatefulWidget {
  const DependenteLoginScreen({super.key});

  @override
  State<DependenteLoginScreen> createState() => _DependenteLoginScreenState();
}

class _DependenteLoginScreenState extends State<DependenteLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cpfCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _cpfF = FocusNode();
  final _pwdF = FocusNode();

  late DependentLoginController _c;
  bool _controllerReady = false;
  bool _navigatingToApp = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllerReady) return;

    final repo = AuthRepository(ApiRouter.client());
    _c = DependentLoginController(
      repo: repo,
      appConfig: AppConfig.maybeOf(context),
    );
    _controllerReady = true;
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

    await pushAndRemoveAllSharedAxis(
      context,
      const RootNavShell(),
      type: SharedAxisTransitionType.vertical,
    );

    _navigatingToApp = false;
  }

  InputDecoration _deco(String label, {String? hint}) => InputDecoration(
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
  );

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Garante aceite dos Termos/Privacidade ANTES do login.
  Future<bool> _ensureTermsForLogin() async {
    if (await ConsentStore.isAccepted()) return true;

    final accepted = await ConsentDialog.show(
      context,
      onOpenPrivacy: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const PrivacidadeScreen(minimal: true),
        ),
      ),
      onOpenTerms: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const TermosScreen(minimal: true),
        ),
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

    // Termos/Privacidade
    if (!await _ensureTermsForLogin()) return;

    final cpfDigits = _cpfCtrl.text.replaceAll(RegExp(r'\D'), '');
    final senha = _pwdCtrl.text;

    final (outcome, message) = await _c.submit(
      rawCpfDigits: cpfDigits,
      password: senha,
    );

    if (!mounted) return;

    switch (outcome) {
      case DependentLoginOutcome.success:
        final vinculos = _c.vinculos;

        if (vinculos.isEmpty) {
          _snack(
            'Nenhum vínculo de titular foi encontrado para este dependente.',
          );
          return;
        }

        // Se só existe 1 vínculo, já finaliza o login e entra no app.
        if (vinculos.length == 1) {
          await _c.finishLoginWithVinculo(vinculos.first);
          if (!mounted) return;
          await _goToApp();
          return;
        }

        // Mais de um vínculo: abre tela para o usuário escolher.
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DependenteVinculoScreen(controller: _c),
          ),
        );
        break;

      case DependentLoginOutcome.error:
        _snack(message ?? 'Falha no login do dependente.');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxW =
    MediaQuery.of(context).size.width > 560 ? 560.0 : double.infinity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Dependente'),
      ),
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
                          decoration: _deco(
                            'CPF do dependente',
                            hint: '00000000000',
                          ),
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
                              decoration: _deco(
                                'Senha do dependente',
                              ),
                              validator: (v) => validatePassword(
                                v,
                                minLen: AppConfig.maybeOf(context)
                                    ?.params
                                    .passwordMinLength ??
                                    4,
                              ),
                              onFieldSubmitted: (_) => _submit(),
                              enabled: !_c.loading.value,
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        ValueListenableBuilder<bool>(
                          valueListenable: _c.loading,
                          builder: (_, busy, __) => SizedBox(
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
                                  valueColor: AlwaysStoppedAnimation(
                                    Colors.white,
                                  ),
                                ),
                              )
                                  : const Text(
                                'Entrar como Dependente',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
                    'Informe o CPF e a senha do dependente para acessar suas informações. '
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

class _LogoBanner extends StatelessWidget {
  const _LogoBanner();
  static const double _h = 90;

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
