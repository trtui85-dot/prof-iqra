import 'dart:convert';

import 'package:crypto/crypto.dart';

/// دوال مشتركة: تجزئة PIN وتطبيع رقم الهاتف
class SecureAuth {
  static String hashPin(String pin) {
    final bytes = utf8.encode('iqra\$#:$pin');
    return sha256.convert(bytes).toString();
  }

  static String normalizePhone(String p) =>
      p.trim().replaceAll(' ', '').replaceAll('-', '');
}