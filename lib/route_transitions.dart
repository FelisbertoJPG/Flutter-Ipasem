// lib/route_transitions.dart
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

// Reexporta o enum para uso externo sem importar 'animations.dart'
export 'package:animations/animations.dart' show SharedAxisTransitionType;

/// PageRoute com Material Motion (Shared Axis).
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final SharedAxisTransitionType type;
  final Duration duration;
  final Duration reverseDuration;
  final Color? fillColor;
  final RouteTransitionsBuilder? transitionBuilder;

  SharedAxisPageRoute({
    required this.child,
    this.type = SharedAxisTransitionType.vertical,
    this.duration = const Duration(milliseconds: 420),
    this.reverseDuration = const Duration(milliseconds: 320),
    this.fillColor,
    this.transitionBuilder,
    RouteSettings? settings,
  }) : super(
    settings: settings,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    pageBuilder: (_, __, ___) => child,
    transitionsBuilder:
    transitionBuilder ?? (context, animation, secondaryAnimation, child) {
      final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      final b = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
      return SharedAxisTransition(
        animation: a,
        secondaryAnimation: b,
        transitionType: type,
        fillColor: fillColor,
        child: child,
      );
    },
  );
}

/// Helper: push com SharedAxis
Future<T?> pushSharedAxis<T>(
    BuildContext context,
    Widget page, {
      SharedAxisTransitionType type = SharedAxisTransitionType.vertical,
      Duration duration = const Duration(milliseconds: 420),
      Duration reverseDuration = const Duration(milliseconds: 320),
      Color? fillColor,
      RouteSettings? settings,
    }) {
  return Navigator.of(context).push(
    SharedAxisPageRoute<T>(
      child: page,
      type: type,
      duration: duration,
      reverseDuration: reverseDuration,
      fillColor: fillColor,
      settings: settings,
    ),
  );
}

/// Helper: pushReplacement com SharedAxis
Future<T?> pushReplacementSharedAxis<T, TO>(
    BuildContext context,
    Widget page, {
      SharedAxisTransitionType type = SharedAxisTransitionType.vertical,
      Duration duration = const Duration(milliseconds: 420),
      Duration reverseDuration = const Duration(milliseconds: 320),
      Color? fillColor,
      RouteSettings? settings,
      TO? result,
    }) {
  return Navigator.of(context).pushReplacement(
    SharedAxisPageRoute<T>(
      child: page,
      type: type,
      duration: duration,
      reverseDuration: reverseDuration,
      fillColor: fillColor,
      settings: settings,
    ),
    result: result,
  );
}

/// Helper: pushAndRemoveUntil (limpa pilha) com SharedAxis
Future<T?> pushAndRemoveAllSharedAxis<T>(
    BuildContext context,
    Widget page, {
      SharedAxisTransitionType type = SharedAxisTransitionType.vertical,
      Duration duration = const Duration(milliseconds: 420),
      Duration reverseDuration = const Duration(milliseconds: 320),
      Color? fillColor,
      RouteSettings? settings,
    }) {
  return Navigator.of(context).pushAndRemoveUntil(
    SharedAxisPageRoute<T>(
      child: page,
      type: type,
      duration: duration,
      reverseDuration: reverseDuration,
      fillColor: fillColor,
      settings: settings,
    ),
        (_) => false,
  );
}
