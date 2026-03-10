import 'package:flutter/material.dart';

class LandaWordmark extends StatelessWidget {
  const LandaWordmark({
    super.key,
    this.fontSize = 22,
    this.colors = const [Color(0xFF163A12), Color(0xFF2D5927)],
    this.letterSpacing = 1.1,
    this.textAlign = TextAlign.left,
    this.withShadow = true,
    this.strokeColor = const Color(0x99203F1A),
    this.strokeWidth = 1.15,
  });

  final double fontSize;
  final List<Color> colors;
  final double letterSpacing;
  final TextAlign textAlign;
  final bool withShadow;
  final Color strokeColor;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontFamily: 'serif',
      fontWeight: FontWeight.w900,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      height: 1,
      shadows: withShadow
          ? const [
              Shadow(
                color: Color(0x290B1D09),
                offset: Offset(0, 1.5),
                blurRadius: 4,
              ),
            ]
          : null,
    );

    return Semantics(
      label: 'LANDA',
      child: ExcludeSemantics(
        child: Stack(
          children: [
            Text(
              'LANDA',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: textAlign,
              style: textStyle.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = strokeWidth
                  ..color = strokeColor,
              ),
            ),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) =>
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ).createShader(
                    Rect.fromLTWH(
                      0,
                      0,
                      bounds.width > 0 ? bounds.width : 120,
                      bounds.height > 0 ? bounds.height : fontSize,
                    ),
                  ),
              child: Text(
                'LANDA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: textAlign,
                style: textStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LandaBrandTitle extends StatelessWidget {
  const LandaBrandTitle({
    super.key,
    this.icon = Icons.radar_rounded,
    this.iconColor = const Color(0xFF2D5927),
    this.wordmarkSize = 28,
    this.wordmarkColors = const [Color(0xFF163A12), Color(0xFF2D5927)],
    this.wordmarkStrokeColor = const Color(0x991B3516),
  });

  final IconData icon;
  final Color iconColor;
  final double wordmarkSize;
  final List<Color> wordmarkColors;
  final Color wordmarkStrokeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: wordmarkSize),
        const SizedBox(width: 8),
        LandaWordmark(
          fontSize: wordmarkSize,
          colors: wordmarkColors,
          letterSpacing: 1.0,
          strokeColor: wordmarkStrokeColor,
          strokeWidth: 0.9,
          withShadow: false,
          textAlign: TextAlign.left,
        ),
      ],
    );
  }
}
