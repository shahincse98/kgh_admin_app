import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'app_routes.dart';

/// Who is signed in, for route guarding.
class Session {
  Session._();

  /// SR document id when the signed-in user is an SR; null for an admin.
  static String? srDocId;

  static bool get isSr => (srDocId ?? '').isNotEmpty;

  static void clear() => srDocId = null;
}

/// Keeps an SR inside the SR panel. The admin pages hold purchase prices,
/// profit and company-wide figures, so an SR must not reach them — not even
/// by typing the address on the web.
class SrGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Session.isSr) return null;
    if (route == AppRoutes.srPanel || route == AppRoutes.login) return null;
    return RouteSettings(name: AppRoutes.srPanel, arguments: Session.srDocId);
  }
}
