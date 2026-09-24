import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/theme.dart';

/// معاينة ملف PDF داخل التطبيق (صفحة A4 كاملة) مع أزرار مشاركة وطباعة
class PdfPreviewPage extends StatelessWidget {
  final Uint8List bytes;
  final String filename;

  const PdfPreviewPage({
    super.key,
    required this.bytes,
    required this.filename,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E6E1),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8E6E1),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'معاينة PDF',
          style: AppText.bold(16),
        ),
        actions: [
          IconButton(
            tooltip: 'مشاركة',
            icon: const Icon(Icons.ios_share, color: AppColors.textDark),
            onPressed: () {
              Printing.sharePdf(bytes: bytes, filename: filename);
            },
          ),
        ],
      ),
      body: PdfPreview(
        build: (_) async => bytes,
        canChangeOrientation: true,
        canChangePageFormat: true,
        canDebug: false,
        allowPrinting: true,
        allowSharing: false,
        pdfFileName: filename,
      ),
    );
  }
}