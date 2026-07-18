import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Opens a color-wheel picker and returns the chosen colour, or null if the
/// customer cancels. [initial] seeds the wheel and brightness slider so editing
/// an existing colour starts from where it was.
Future<Color?> showColorWheelDialog(
  BuildContext context, {
  required Color initial,
  String title = 'Pick a colour',
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _ColorWheelDialog(initial: initial, title: title),
  );
}

/// The 6-hex RRGGBB form of a colour.
String _hex6(Color c) =>
    (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');

class _ColorWheelDialog extends StatefulWidget {
  final Color initial;
  final String title;
  const _ColorWheelDialog({required this.initial, required this.title});

  @override
  State<_ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<_ColorWheelDialog> {
  // HSV lets the wheel map hue→angle and saturation→radius, with value on a
  // separate brightness slider — the standard, intuitive colour-wheel model.
  late double _hue; // 0..360
  late double _sat; // 0..1
  late double _val; // 0..1

  static const double _wheel = 240;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initial);
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value == 0 ? 1.0 : hsv.value;
  }

  Color get _color => HSVColor.fromAHSV(1, _hue, _sat, _val).toColor();

  void _onWheel(Offset local) {
    const r = _wheel / 2;
    final dx = local.dx - r;
    final dy = local.dy - r;
    final dist = math.sqrt(dx * dx + dy * dy);
    setState(() {
      _hue = (math.atan2(dy, dx) * 180 / math.pi + 360) % 360;
      _sat = (dist / r).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, style: const TextStyle(fontSize: 17)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: _wheel,
              height: _wheel,
              child: GestureDetector(
                onPanDown: (d) => _onWheel(d.localPosition),
                onPanUpdate: (d) => _onWheel(d.localPosition),
                child: CustomPaint(
                  painter: _WheelPainter(hue: _hue, sat: _sat, val: _val),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.brightness_6, size: 20, color: Colors.black54),
                Expanded(
                  child: Slider(
                    value: _val,
                    min: 0,
                    max: 1,
                    activeColor: const Color(0xFF00897B),
                    onChanged: (v) => setState(() => _val = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _color,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '#${_hex6(_color).toUpperCase()}',
                  style: const TextStyle(fontSize: 15, letterSpacing: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _color),
          child: const Text('Use colour'),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  final double hue, sat, val;
  const _WheelPainter({required this.hue, required this.sat, required this.val});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Hue around the circle (sweep gradient), full saturation at the rim.
    final hueShader = SweepGradient(
      colors: [
        for (int i = 0; i <= 360; i += 60)
          HSVColor.fromAHSV(1, i % 360.0, 1, 1).toColor(),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, Paint()..shader = hueShader);

    // White in the middle fading out to the rim = decreasing saturation.
    final satShader = RadialGradient(
      colors: [Colors.white, Colors.white.withValues(alpha: 0)],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, Paint()..shader = satShader);

    // Brightness: darken the whole disc as value drops.
    if (val < 1) {
      canvas.drawCircle(center, radius,
          Paint()..color = Colors.black.withValues(alpha: 1 - val));
    }

    // Selector ring at the current hue/saturation position.
    final ang = hue * math.pi / 180;
    final sel = center + Offset(math.cos(ang), math.sin(ang)) * (sat * radius);
    canvas.drawCircle(sel, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
        sel,
        9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black54);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) =>
      old.hue != hue || old.sat != sat || old.val != val;
}
