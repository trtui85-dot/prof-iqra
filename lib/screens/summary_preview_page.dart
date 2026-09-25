import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/summary_service.dart';
import '../widgets/landscape_cards.dart';

/// معاينة جميلة للبطاقة/التقرير وحفظه كصورة أفقية في معرض الصور.
class SummaryPreviewPage extends StatefulWidget {
  final String title;
  final String fileName;
  final Widget card;
  const SummaryPreviewPage({
    super.key,
    required this.title,
    required this.fileName,
    required this.card,
  });

  @override
  State<SummaryPreviewPage> createState() => _SummaryPreviewPageState();
}

class _SummaryPreviewPageState extends State<SummaryPreviewPage> {
  final _cardKey = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (!await Gal.hasAccess(toAlbum: false)) {
        if (!await Gal.requestAccess()) {
          if (mounted) showError(context, 'لم يُمنح إذن الوصول إلى معرض الصور.');
          return;
        }
      }
      final bytes = await captureWidget(_cardKey);
      await Gal.putImageBytes(bytes, name: widget.fileName);
      if (mounted) showSuccess(context, 'تم حفظ الصورة في المعرض.');
    } catch (e) {
      if (mounted) showError(context, 'تعذّر حفظ الصورة في المعرض.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  child: AspectRatio(
                    aspectRatio: kSummaryWidth / kSummaryHeight,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: SizedBox(
                          width: kSummaryWidth,
                          height: kSummaryHeight,
                          child: widget.card,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Icon(Icons.download_rounded),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ في المعرض'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}