import 'package:flutter/material.dart';
// Deprecated: use AppRouter in app_router.dart
// Kept for backward compatibility; routes are forwarded to AppRouter.
import 'app_router.dart';
import 'package:flutter/material.dart';

class AppRoutes {
  static Route onGenerateRoute(RouteSettings settings) =>
      AppRouter.onGenerateRoute(settings);
}
