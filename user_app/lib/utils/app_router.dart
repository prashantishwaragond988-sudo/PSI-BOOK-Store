import "package:flutter/material.dart";

import "../screens/about_screen.dart";
import "../screens/checkout_screen.dart";
import "../screens/forgot_password_screen.dart";
import "../screens/help_screen.dart";
import "../screens/login_screen.dart";
import "../screens/root_shell.dart";
import "../screens/order_tracking_screen.dart";
import "../screens/order_success_screen.dart";
import "../screens/payment_screen.dart";
import "../screens/settings_screen.dart";
import "../screens/splash_screen.dart";
import "../screens/verify_email_screen.dart";
import "../screens/orders_screen.dart";
import "../screens/wishlist_screen.dart";
import "../screens/coupons_screen.dart";

class AppRouter {
  static const splash = "/splash";
  static const login = "/login";
  static const verifyEmail = "/verify-email";
  static const forgotPassword = "/forgot-password";
  static const main = "/main";
  static const checkout = "/checkout";
  static const payment = "/payment";
  static const orderSuccess = "/order-success";
  static const orderTracking = "/order-tracking";
  static const help = "/help";
  static const about = "/about";
  static const settings = "/settings";
  static const orders = "/orders";
  static const wishlist = "/wishlist";
  static const coupons = "/coupons";

  static Route<dynamic> slide(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideTween = Tween<Offset>(
          begin: const Offset(0.14, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        final fadeTween = Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut));

        return FadeTransition(
          opacity: animation.drive(fadeTween),
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
      },
    );
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case splash:
        return slide(const SplashScreen());
      case login:
        return slide(const LoginScreen());
      case verifyEmail:
        return slide(const VerifyEmailScreen());
      case forgotPassword:
        return slide(const ForgotPasswordScreen());
      case main:
        final initialIndex =
            routeSettings.arguments is int ? routeSettings.arguments as int : 0;
        return slide(RootShell(initialIndex: initialIndex));
      case checkout:
        return slide(const CheckoutScreen());
      case payment:
        final args = routeSettings.arguments;
        if (args is PaymentScreenArgs) {
          return slide(PaymentScreen(args: args));
        }
        if (args is String && args.trim().isNotEmpty) {
          return slide(PaymentScreen(args: PaymentScreenArgs(addressId: args)));
        }
        return slide(const CheckoutScreen());
      case orderSuccess:
        final orderId = routeSettings.arguments is String
            ? routeSettings.arguments as String
            : "";
        return slide(OrderSuccessScreen(orderId: orderId));
      case orderTracking:
        final orderId = routeSettings.arguments is String
            ? routeSettings.arguments as String
            : "";
        return slide(OrderTrackingScreen(orderId: orderId));
      case help:
        return slide(const HelpScreen());
      case about:
        return slide(const AboutScreen());
      case settings:
        return slide(const SettingsScreen());
      case orders:
        return slide(const OrdersScreen());
      case wishlist:
        return slide(const WishlistScreen());
      case coupons:
        return slide(const CouponsScreen());
      default:
        return slide(const SplashScreen());
    }
  }
}
