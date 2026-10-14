import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An old vinyl record whose center label is [imagePath]. Only the disc
/// rotates; the light sheen and the tonearm stay still, like a real turntable.
class VinylRecord extends StatelessWidget {
  final String imagePath;
  final double size;
  final Animation<double> turns;
  final bool isPlaying;
  final Object heroTag;

  const VinylRecord({
    super.key,
    required this.imagePath,
    required this.size,
    required this.turns,
    required this.isPlaying,
    required this.heroTag,
  });

  static const _labelFraction = 0.46;

  // Tonearm geometry, as fractions of the disc size, relative to its top-left.
  static const _pivotX = 1.03;
  static const _pivotY = -0.03;
  static const _armLength = 0.62;
  static const _armBase = 0.17;
  static const _restAngle = -0.06;
  static const _playAngle = 0.28;

  @override
  Widget build(BuildContext context) {
    final labelSize = size * _labelFraction;
    final base = size * _armBase;
    final armBoxHeight = size * _armLength + base;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The boundary sits inside the rotation, so the disc is painted
          // once and each frame only the rotation angle changes.
          RotationTransition(
            turns: turns,
            child: Hero(
              tag: heroTag,
              child: RepaintBoundary(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size.square(size),
                      painter: _DiscPainter(labelFraction: _labelFraction),
                    ),
                    ClipOval(
                      child: Image.asset(
                        imagePath,
                        width: labelSize,
                        height: labelSize,
                        cacheWidth: 400,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: labelSize,
                          height: labelSize,
                          color: const Color(0xFF8D6E63),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            size: 48,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    CustomPaint(
                      size: Size.square(size),
                      painter: _LabelRimPainter(labelFraction: _labelFraction),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size.square(size),
                painter: _SheenPainter(),
              ),
            ),
          ),
          Positioned(
            left: size * _pivotX - base / 2,
            top: size * _pivotY - base / 2,
            width: base,
            height: armBoxHeight,
            child: AnimatedRotation(
              turns: (isPlaying ? _playAngle : _restAngle) / (2 * math.pi),
              alignment: Alignment(0, base / armBoxHeight - 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeInOutCubic,
              child: RepaintBoundary(
                child: CustomPaint(painter: _TonearmPainter()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscPainter extends CustomPainter {
  final double labelFraction;
  _DiscPainter({required this.labelFraction});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final labelR = r * labelFraction;

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF231C19), Color(0xFF110D0C), Color(0xFF070505)],
          stops: [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Fine grooves, with a few wider gaps between tracks.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;
    final gaps = [0.62, 0.74, 0.86];
    var i = 0;
    for (var gr = labelR + 6; gr < r - 5; gr += 2.2, i++) {
      final f = gr / r;
      final inGap = gaps.any((g) => (f - g).abs() < 0.008);
      groove.color = inGap
          ? const Color(0xFF020101)
          : Color.fromARGB(i.isEven ? 34 : 18, 255, 240, 225);
      groove.strokeWidth = inGap ? 2.0 : 0.6;
      canvas.drawCircle(c, gr, groove);
    }

    // Light scratches from years of use.
    final rnd = math.Random(7);
    final scratch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 14; k++) {
      final sr = labelR + 10 + rnd.nextDouble() * (r - labelR - 18);
      final start = rnd.nextDouble() * 2 * math.pi;
      scratch
        ..strokeWidth = 0.5 + rnd.nextDouble() * 0.6
        ..color = Color.fromARGB(25 + rnd.nextInt(30), 255, 245, 230);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: sr),
        start,
        0.15 + rnd.nextDouble() * 0.5,
        false,
        scratch,
      );
    }

    // Raised lead-out ring next to the label, and the outer rim.
    canvas.drawCircle(
      c,
      labelR + 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF1E1714),
    );
    canvas.drawCircle(
      c,
      r - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFF2A211D),
    );
  }

  @override
  bool shouldRepaint(_DiscPainter old) => old.labelFraction != labelFraction;
}

class _LabelRimPainter extends CustomPainter {
  final double labelFraction;
  _LabelRimPainter({required this.labelFraction});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final labelR = size.width / 2 * labelFraction;

    // Aged paper edge and a faint inner line, like a printed label.
    canvas.drawCircle(
      c,
      labelR - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFCDB68E),
    );
    canvas.drawCircle(
      c,
      labelR - 6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x88E8D9B5),
    );
    // A warm wash so the photo looks printed long ago.
    canvas.drawCircle(c, labelR - 3, Paint()..color = const Color(0x2A8B5A2B));
  }

  @override
  bool shouldRepaint(_LabelRimPainter old) =>
      old.labelFraction != labelFraction;
}

/// Light reflected by the vinyl; it stays put while the disc turns under it.
class _SheenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width / 2,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0x00FFFFFF),
            Color(0x26FFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x1CFFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0.0, 0.10, 0.2, 0.5, 0.60, 0.7, 1.0],
          transform: GradientRotation(-0.6),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) => false;
}

/// Pivot at the top center of the box, the arm hanging straight down.
class _TonearmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final pivot = Offset(w / 2, w / 2);
    final headTop = size.height - w * 0.55;

    // Base.
    canvas.drawCircle(
      pivot.translate(0, 3),
      w / 2,
      Paint()..color = const Color(0x66000000),
    );
    canvas.drawCircle(
      pivot,
      w / 2,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [Color(0xFFEDE6DA), Color(0xFF9E9488), Color(0xFF5E564E)],
        ).createShader(Rect.fromCircle(center: pivot, radius: w / 2)),
    );
    canvas.drawCircle(
      pivot,
      w * 0.18,
      Paint()..color = const Color(0xFF3B3430),
    );

    // Arm, with a slight bend near the head like an S-shaped tonearm.
    final arm = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(pivot.dx, headTop - w * 0.6)
      ..quadraticBezierTo(
        pivot.dx,
        headTop - w * 0.2,
        pivot.dx - w * 0.14,
        headTop,
      );
    canvas.drawPath(
      arm,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.13
        ..color = const Color(0x55000000),
    );
    canvas.drawPath(
      arm,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = w * 0.09
        ..shader = const LinearGradient(
          colors: [Color(0xFFF2EDE4), Color(0xFFA39A8F)],
        ).createShader(Offset.zero & size),
    );

    // Headshell.
    final head = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pivot.dx - w * 0.14, headTop + w * 0.22),
        width: w * 0.34,
        height: w * 0.5,
      ),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(head, Paint()..color = const Color(0xFF2B2522));
    canvas.drawRRect(
      head,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFF8A8076),
    );
  }

  @override
  bool shouldRepaint(_TonearmPainter old) => false;
}
