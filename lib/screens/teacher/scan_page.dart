import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../models/app_user.dart';
import '../../services/attendance_service.dart';

enum _Phase { scanning, busy, success, error }

class ScanPage extends StatefulWidget {
  final AppUser teacher;
  const ScanPage({super.key, required this.teacher});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _controller =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  final _attendance = AttendanceService();

  _Phase _phase = _Phase.scanning;
  ScanResult? _result;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_phase == _Phase.busy) return;
    final barcode = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first;
    final payload = barcode?.rawValue;
    if (payload == null || payload.isEmpty) return;

    setState(() => _phase = _Phase.busy);
    try {
      final valid = await _attendance.verifyQr(payload);
      if (!valid) {
        if (mounted) {
          setState(() {
            _phase = _Phase.error;
            _result = null;
            _error = 'رمز غير صالح.\nهذا ليس كود الإدارة الحالي.';
          });
        }
        return;
      }
      final result = await _attendance.scan(widget.teacher);
      if (mounted) {
        setState(() {
          _phase = _Phase.success;
          _result = result;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _phase = _Phase.error;
          _result = null;
          _error = e.toString();
        });
      }
    }
  }

  void _resume() {
    setState(() => _phase = _Phase.scanning);
    _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildScanner(),
          const SizedBox(height: 20),
          if (_phase == _Phase.success) _buildSuccess() else if (_phase == _Phase.error) _buildError() else _buildHint(),
        ],
      ),
    );
  }

  Widget _buildScanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1.05,
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Container(
                color: AppColors.surface,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.no_photography_outlined,
                          color: AppColors.textMuted, size: 40),
                      const SizedBox(height: 12),
                      Text('تعذّر فتح الكاميرا.\nتحقق من إذن الكاميرا في الإعدادات.',
                          style: AppText.muted(13),
                          textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
            if (_phase == _Phase.scanning || _phase == _Phase.busy)
              CustomPaint(
                painter: _ScanOverlayPainter(),
                child: const SizedBox.expand(),
              ),
            if (_phase == _Phase.busy)
              Container(
                color: Colors.black.withValues(alpha: .3),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHint() {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'وجّه الكاميرا نحو رمز QR الخاص بالإدارة. '
              'المسح الأول يسجّل حضورك، والمسح الثاني يسجّل انصرافك.',
              style: AppText.normal(13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final r = _result!;
    final isCheckOut = r.kind == ScanKind.checkOut;
    final late = r.status == 'late';
    final time = _fmt(r.when);
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: late ? AppColors.lateSoft : AppColors.presentSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Icon(
            isCheckOut ? Icons.logout : Icons.login,
            color: late ? AppColors.late : AppColors.present,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCheckOut ? 'تم تسجيل انصرافك' : 'تم تسجيل حضورك',
                  style: AppText.bold(16).copyWith(
                    color: late ? AppColors.late : AppColors.present,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'حصة «${r.entry.className}» • الساعة $time',
                  style: AppText.normal(13.5),
                ),
                if (late)
                  Text('سُجّل كمتأخر عن الموعد.'.trim(),
                      style: AppText.bold(12.5).copyWith(color: AppColors.late)),
              ],
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: _resume,
        icon: const Icon(Icons.replay),
        label: const Text('مسح مرة أخرى'),
      ),
    ]);
  }

  Widget _buildError() {
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.absentSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: AppColors.absent, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Text(_error ?? 'حدث خطأ.',
                style: AppText.normal(14).copyWith(color: AppColors.textDark)),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: _resume,
        icon: const Icon(Icons.replay),
        label: const Text('إعادة المحاولة'),
      ),
    ]);
  }

  static String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * .72,
      height: size.width * .72,
    );
    final cutout = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)));

    canvas.drawPath(cutout, Paint()..color = Colors.black26);
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(20)),
      border,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}