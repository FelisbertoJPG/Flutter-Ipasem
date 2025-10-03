# IPASEM App (Flutter)

Aplicativo Flutter do IPASEM com três telas principais: **Home**, **Serviços** (carteirinha/assistência) e **Perfil**. Interface consistente, responsiva e com navegação por **AppBar + Drawer** (menu hambúrguer).

## Sumário
- [Arquitetura & Telas](#arquitetura--telas)
- [Padrões de UI/UX](#padrões-de-uiux)
- [Estado e Preferências](#estado-e-preferências)
- [WebView & Performance](#webview--performance)
- [Estrutura de Pastas](#estrutura-de-pastas)
- [Requisitos](#requisitos)
- [Como rodar](#como-rodar)
- [Build (Android/iOS)](#build-androidios)
- [Ambiente & Configurações úteis](#ambiente--configurações-úteis)
- [Roadmap](#roadmap)
- [Contribuindo](#contribuindo)
- [Licença](#licença)

---

## Arquitetura & Telas

**Home**
- Arquivo: `lib/home_screen.dart`
- Classe: `HomeScreen`
- Seções: Cabeçalho Visitante/Logado, Ações rápidas (navegam para Serviços), Minha Situação, Requerimentos em andamento, Comunicados.
- Pull-to-refresh e layout responsivo.

**Serviços**
- Arquivo: `lib/home_servicos.dart`
- Classe: `HomeServicos`
- Ações: Autorizações (WebView + CPF), Carteirinha Digital, Site.
- Pré-aquecimento de WebView com `OverlayEntry` para primeira navegação rápida.

**Perfil**
- Arquivo: `lib/profile_screen.dart`
- Classe: `ProfileScreen`
- Modo visitante por padrão, cards de dados bloqueados, itens informativos e **Sair**.

**Outras telas utilitárias**
- `login_screen.dart` (placeholder para fluxo de login real)
- `webview_screen.dart` (renderização de páginas dentro do app)

Navegação entre telas via `Navigator.push` a partir do Drawer e das ações rápidas.

---

## Padrões de UI/UX

- **AppBar** com menu hambúrguer + logo (componente `_LogoAction`).
- **Drawer** com seções: Serviços, Perfil, Sair.
- Paleta compartilhada:
  - `Color(0xFF143C8D)` (brand), `_cardBg`, `_cardBorder`, `_panelBg`, `_panelBorder`.
- **Cards utilitários**: `_SectionCard`, `_StatusChip`, placeholders de loading e empty states.
- **Responsividade**: `LayoutBuilder + ConstrainedBox`, botões largos, `Wrap` para 1–2 colunas.

---

## Estado e Preferências

Sem backend de autenticação por enquanto. O app usa `SharedPreferences`:

- `is_logged_in: bool` — controla estado Visitante/Logado (padrão `false`).
- `saved_cpf: String` — usado para autofill na tela de Autorizações/Carteirinha.
- `auth_token: String?` — reservado para futura integração.

> Logout limpa `saved_cpf`, `auth_token` e seta `is_logged_in = false`.

---

## WebView & Performance

- **webview_flutter** com `JavaScriptMode.unrestricted`.
- **Pré-aquecimento**: `home_servicos.dart` injeta um `WebViewWidget` invisível via `OverlayEntry` para acelerar a primeira navegação.
- Transição customizada via `_softSlideRoute`.

---

## Estrutura de Pastas

```
lib/
  home_screen.dart         # Home
  home_servicos.dart       # Serviços (carteirinha/autorizações/site)
  profile_screen.dart      # Perfil
  login_screen.dart        # (stub) fluxo de login
  webview_screen.dart      # wrapper de WebView
assets/
  images/
    icons/
      logo_ipasem.png
```

> Lembre-se de declarar os assets no `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/images/icons/logo_ipasem.png
```

---

## Requisitos

- Flutter (canal stable) instalado.
- Dart SDK vindo com o Flutter.
- Android Studio / Xcode configurados para emuladores/dispositivos.

---

## Como rodar

```bash
# Verifique o ambiente
flutter doctor

# Instale dependências
flutter pub get

# Rode no dispositivo/emulador conectado
flutter run
```

---

## Build (Android/iOS)

**Android**
```bash
flutter build apk --release
# ou
flutter build appbundle --release
```
Permissões recomendadas (em `AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

**iOS**
```bash
flutter build ios --release
```
No iOS, revise `Info.plist` para `NSAppTransportSecurity` (ATS) caso acesse URLs não-HTTPS (ideal manter HTTPS).

---

## Ambiente & Configurações úteis

- **Chaves/Endpoints**: quando integrar backend, prefira `.env`/flavors.
- **Logs**: use `debugPrint` e, futuramente, um serviço de logging/analytics.
- **Acessibilidade**: fontes escaláveis, contraste adequado, labels em ícones.

---

## Roadmap

- [ ] Integração real de login (autenticação + token).
- [ ] Tela de “Minhas Autorizações” (histórico) e “Meus Documentos”.
- [ ] Cache offline de carteirinha (com expiração).
- [ ] Tema claro/escuro.
- [ ] Testes widget/dart e CI.

---

## Contribuindo

1. Crie uma branch a partir de `main`.
2. Faça commits pequenos e descritivos.
3. Abra PR com descrição, screenshots e passos de teste.

---

## Licença

Defina a licença do projeto (ex.: MIT, Apache-2.0) em `LICENSE`.
