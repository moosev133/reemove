import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class ReeMoveLogo extends StatelessWidget {
  const ReeMoveLogo({super.key, this.size = 56, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final Widget mark = Semantics(
      label: 'ReeMove logo',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _ReeMoveMarkPainter()),
      ),
    );

    if (!showWordmark) {
      return mark;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        mark,
        SizedBox(width: size * 0.22),
        Text(
          'ReeMove',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
          ),
        ),
      ],
    );
  }
}

class _ReeMoveMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Paint background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[AppColors.brand, AppColors.brandDeep],
      ).createShader(bounds);

    final RRect shell = RRect.fromRectAndRadius(
      bounds.deflate(size.width * 0.03),
      Radius.circular(size.width * 0.30),
    );
    canvas.drawRRect(shell, background);

    final Paint line = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.105;

    final Path path = Path()
      ..moveTo(size.width * 0.29, size.height * 0.70)
      ..lineTo(size.width * 0.29, size.height * 0.31)
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.22,
        size.width * 0.69,
        size.height * 0.43,
      )
      ..quadraticBezierTo(
        size.width * 0.63,
        size.height * 0.60,
        size.width * 0.43,
        size.height * 0.54,
      )
      ..lineTo(size.width * 0.72, size.height * 0.73);
    canvas.drawPath(path, line);

    final Paint energy = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(size.width * 0.75, size.height * 0.21);
    canvas.rotate(-math.pi / 7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * 0.10,
          height: size.height * 0.22,
        ),
        Radius.circular(size.width * 0.05),
      ),
      energy,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
