IPASEM App (Flutter)

Aplicativo Flutter do IPASEM com três áreas principais: Home, Serviços e Perfil. Interface consistente, responsiva e com navegação por AppBar + Drawer.

Sumário

Arquitetura & Telas

Novidades (feats/fix)

Padrões de UI/UX

Estado e Preferências

Notificações (Android/iOS)

WebView & Performance

Estrutura de Pastas

Requisitos

Como rodar

Build (Android/iOS)

Ambiente & Configurações úteis

Roadmap

Contribuindo

Licença

Arquitetura & Telas

Home
lib/screens/home_screen.dart
Apresenta cabeçalhos para visitante/logado, Ações rápidas, situação do usuário e comunicados. Mostro também:

Autorizações de Exames (liberadas) – ExamesLiberadosCard

Autorizações de Exames (pendentes) – ExamesPendentesCard

Histórico de Autorizações (resumo) – limitado às 5 mais recentes por data (com “Ver tudo”).

Serviços
lib/screens/home_servicos.dart
Acesso às funcionalidades principais:

Autorização Médica, Odontológica e Autorização de Exames (nova).

Carteirinha Digital e Site.
Pré-aqueço a WebView para navegações mais rápidas.

Histórico de Autorizações (completo)
lib/screens/historico_autorizacoes_screen.dart
Lista paginada do histórico com 10 itens por página, ordenado por data/hora (mais recentes primeiro), integração com reimpressão e detalhes.

Fluxos de autorização

Médica: lib/screens/autorizacao_medica_screen.dart

Odontológica: lib/screens/autorizacao_odontologica_screen.dart

Exames (novo): lib/screens/autorizacao_exames_screen.dart

PDF / Impressão local
lib/ui/utils/print_helpers.dart
Abro o preview/print do PDF pelo número da autorização, decidindo automaticamente o tipo.

Novidades (feats/fix)

Exames – nova solicitação com upload de até 2 imagens, escolha de especialidade, cidade e prestador.

Cartões na Home

Exames Liberados com acesso ao detalhe e atalho para imprimir no app.

Exames Pendentes com banner de “mudança de situação” (sino/aviso) baseado em snapshot local.

Histórico completo com paginação (10 por página) e ordenação por data/hora.

Resumo do histórico na Home limitado às 5 últimas autorizações (ordenadas).

Auto-refresh centralizado via AuthEvents:

Atualizo cartões/listas quando uma autorização é emitida ou quando ocorre a primeira impressão.

Notificações locais (Android/iOS):

Serviço lib/services/notifier.dart com inicialização e canal padrão.

Solicitação de permissão no primeiro uso (Android 13+ e iOS).

Correções:

Acesso a InheritedWidget movido de initState para didChangeDependencies nas telas que precisam de AppConfig.

Normalização de “paciente” vazio com fallback do titular apenas para exibição (sem alterar o modelo).

Padrões de UI/UX

AppBar com menu hambúrguer + logo.

Paleta compartilhada (brand #143C8D) e componentes reutilizáveis (SectionCard, placeholders, empty states).

Layouts responsivos com LayoutBuilder e Wrap.

Sheets de ação/detalhe para reimpressão:
lib/ui/components/reimp_action_sheet.dart e lib/ui/components/reimp_detalhes_sheet.dart.

Estado e Preferências

Uso SharedPreferences para:

is_logged_in: bool

saved_cpf: String

auth_token: String? (reservado)

Snapshot de pendências de exames para detectar mudanças de situação.

Logout limpa as chaves e retorna ao modo visitante.

Notificações (Android/iOS)

Biblioteca: flutter_local_notifications (17+).
Serviço: lib/services/notifier.dart com AppNotifier.init() e AppNotifier.requestPermissionIfNeeded() no main.dart/main_local.dart.

Android

Manifest:

<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />


android/app/build.gradle (KTS) – habilito desugaring (requisito do plugin):

android {
compileOptions {
sourceCompatibility = JavaVersion.VERSION_11
targetCompatibility = JavaVersion.VERSION_11
isCoreLibraryDesugaringEnabled = true
}
}
dependencies {
coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}


O canal padrão é criado em AppNotifier.init().

iOS

Solicito permissão em tempo de execução via flutter_local_notifications.

Revisar Info.plist caso haja necessidade de chaves de notificação/ATS.

WebView & Performance

webview_flutter com JavaScriptMode.unrestricted.

Pré-aquecimento de WebView (overlay invisível) para reduzir o tempo da primeira navegação.

Transições suaves com rota customizada.

Estrutura de Pastas
lib/
config/                    # AppConfig + Params (flavors)
controllers/               # HomeServicosController (histórico, detalhes)
models/                    # Reimpressao, Exame, etc.
pdf/                       # mapeadores/dados para PDF
repositories/              # acesso à API (DevApi) e endpoints
screens/
home_screen.dart
home_servicos.dart
profile_screen.dart
login_screen.dart
historico_autorizacoes_screen.dart
autorizacao_medica_screen.dart
autorizacao_odontologica_screen.dart
autorizacao_exames_screen.dart
services/
dev_api.dart
notifier.dart            # notificações locais
session.dart
state/
auth_events.dart         # eventos para auto-refresh (emit/observe)
ui/
app_shell.dart
components/
section_card.dart
loading_placeholder.dart
reimp_action_sheet.dart
reimp_detalhes_sheet.dart
exames_liberados_card.dart
exames_pendentes_card.dart
utils/
print_helpers.dart
service_launcher.dart
webview_warmup.dart
widgets/
history_list.dart

Requisitos

Flutter (canal stable)

Dart SDK (incluso no Flutter)

Android Studio / Xcode configurados

Como rodar
flutter doctor
flutter pub get
flutter run


Para trocar a base da API em dev/local, uso --dart-define (ex.: API_BASE).

Build (Android/iOS)

Android

flutter build apk --release
# ou
flutter build appbundle --release


Permissão obrigatória no AndroidManifest.xml:

<uses-permission android:name="android.permission.INTERNET" />


Se for usar notificações, manter a permissão POST_NOTIFICATIONS e a configuração de desugaring acima.

iOS

flutter build ios --release


Revisar Info.plist para permissões e ATS. Testar em dispositivo físico para validar notificações.

Ambiente & Configurações úteis

AppConfig centraliza parâmetros (ex.: baseApiUrl) e flavors.

Logs com debugPrint.

Acessibilidade: fontes escaláveis, labels e contraste verificados nos principais componentes.