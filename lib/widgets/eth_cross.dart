import 'package:flutter/material.dart';

class EthCross extends StatelessWidget {
  const EthCross({
    super.key,
    this.size = 28,
    this.opacity = 1.0,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size * 1.14,
        child: Image.asset(
          'assets/images/splash.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
