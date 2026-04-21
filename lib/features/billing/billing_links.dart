import 'package:flutter/foundation.dart';

Uri? billingManagementUri() {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return Uri.parse('https://apps.apple.com/account/subscriptions');
    case TargetPlatform.android:
      return Uri.parse('https://play.google.com/store/account/subscriptions');
    default:
      return null;
  }
}
