#!/usr/bin/env bash
flutter build apk -t lib/main.dart \
  --release \
  --dart-define=APP_FLAVOR=prod \
  --dart-define=SUPPORT_EMAIL=suporte@ipasemnh.com.br \
  --dart-define=SENDER_EMAIL=naoresponder@ipasemnh.com.br \
  --dart-define=USER_PASSWORD_RESET_TOKEN_EXPIRE=3600 \
  --dart-define=USER_PASSWORD_MIN_LENGTH=8
