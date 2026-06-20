import 'dart:async';

import 'package:flutter/services.dart';

class ClipboardHelper {
  static Timer? _clearTimer;

  static Future<void> copyToClipboard(
    String text, {
    Duration clearAfter = const Duration(seconds: 30),
  }) async {
    await Clipboard.setData(ClipboardData(text: text));

    _clearTimer?.cancel();
    _clearTimer = Timer(clearAfter, () async {
      final current = await getClipboardText();
      if (current == text) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  static Future<String?> getClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
