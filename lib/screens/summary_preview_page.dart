import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../core/theme.dart';
import '../core/widgets.dart';
import '../services/summary_service.dart';
import '../widgets/landscape_cards.dart';

/// معاينة جميلة للبطاقة/التقرير: صفحات أفقية، تكبير باللمس، وحفظ الصور في المعرض.
class SummaryPreviewPage extends StatefulWidget {
  final String title;
  final String fileName; // الاسم الأساسي بدون امتداد
  final List<Widget> cards;
  const SummaryPreviewPage({
    super.key,
    required this.title,
    required this.fileName,
    required this.cards,
  });

  @override
  State<SummaryPreviewPage> createState() => _SummaryPreviewPageState();
}

class _SummaryPreviewPageState extends State<SummaryPreviewPage> {
  final _controller = PageController();
  late final List<GlobalKey> _keys =
      List.generate(widget.cards.length, (_) => GlobalKey());
  int _page = 0;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    var saved = 0;
    try {
      if (!await Gal.hasAccess(toAlbum: false)) {
        if (!await Gal.requestAccess()) {
          if (mounted) showError(context, 'لم يُمنح إذن الوصول إلى معرض الصور.');
          return;
        }
      }
      for (var i = 0; i < _keys.length; i++) {
        final bytes = await captureWidget(_keys[i]);
        final name = _keys.length > 1 ? '${widget.fileName}-${i + 1}' : widget.fileName;
        await Gal.putImageBytes(bytes, name: name);
        saved++;
      }
      if (mounted) showSuccess(context, 'تم حفظ $saved صورة في المعرض.');
    } catch (e) {
      if (mounted) showError(context, 'تعذّر حفظ الصور في المعرض.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.cards.length > 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: widget.cards.length,
                itemBuilder: (context, i) {
                  return InteractiveViewer(
                    maxScale: 4,
                    minScale: 1,
                    panEnabled: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: kSummaryWidth / kSummaryHeight,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: RepaintBoundary(
                              key: _keys[i],
                              child: SizedBox(
                                width: kSummaryWidth,
                                height: kSummaryHeight,
                                child: widget.cards[i],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (multi)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.cards.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? AppColors.primary
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'اسحب بين الصفحات • يمكنك عمل Zoom بالضغط باصبعين',
                style: AppText.muted(11),
                textAlign: TextAlign.center,
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
                label: Text(_saving
                    ? 'جارٍ الحفظ...'
                    : multi
                        ? 'حفظ كل الصور في المعرض'
                        : 'حفظ في المعرض'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}