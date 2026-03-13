import 'package:flutter/material.dart';

/// Returns a human-readable "time ago" string localised to the app's current
/// language (en / ms / id / zh).  Uses [BuildContext] to resolve the locale
/// so callers don't need to pass the locale string manually.
String localizedTimeAgo(DateTime dt, BuildContext context) {
  final locale = Localizations.localeOf(context).languageCode;
  final diff = DateTime.now().difference(dt);

  switch (locale) {
    case 'ms':
      if (diff.inMinutes < 1) return 'Baru sahaja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      return '${diff.inDays} hari lalu';

    case 'id':
      if (diff.inMinutes < 1) return 'Baru saja';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
      if (diff.inHours < 24) return '${diff.inHours} jam lalu';
      return '${diff.inDays} hari lalu';

    case 'zh':
      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      return '${diff.inDays}天前';

    default: // 'en'
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
  }
}
