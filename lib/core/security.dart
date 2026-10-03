import 'dart:convert';

import 'package:crypto/crypto.dart';

/// دوال مشتركة: تجزئة PIN وتطبيع رقم الهاتف
class SecureAuth {
  static String hashPin(String pin) {
    final bytes = utf8.encode('iqra\$#:$pin');
    return sha256.convert(bytes).toString();
  }

  /// تطبيع رقم الهاتف: يقبل الصيغ مع أو بدون رمز الدولة
  /// (+222 موريتانيا، +212 المغرب، أو 00222/00212) ويزيل الفواصل.
  static String normalizePhone(String p) {
    var v = p.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (v.startsWith('+')) v = v.substring(1);
    if (v.startsWith('00')) v = v.substring(2);
    for (final cc in const ['222', '212']) {
      if (v.startsWith(cc) && v.length - cc.length >= 8) {
        v = v.substring(cc.length);
        break;
      }
    }
    return v;
  }

  /// كل الصيغ الممكنة للرقم المُدخل، للبحث في قاعدة البيانات:
  /// كما هو، مع صفر بادئة، وبدون صفر بادئة (تغطية كل صيغ الإدخال).
  static List<String> phoneCandidates(String p) {
    final v = normalizePhone(p);
    final set = <String>{v};
    if (!v.startsWith('0')) {
      set.add('0$v');
    } else if (v.length > 1) {
      set.add(v.substring(1));
    }
    return set.toList();
  }
}