import 'package:flutter/material.dart';
import '../core/colors.dart';
import '../core/audio_global.dart';

/// Widget de Ecualizador / Onda de sonido animada en vivo.
/// Muestra barras dinámicas que reaccionan cuando la música o audiolibro están reproduciéndose.
class OndaSonidoAnimada extends StatefulWidget {
  final double height;
  final Color color;
  final int barCount;

  const OndaSonidoAnimada({
    super.key,
    this.height = 18.0,
    this.color = ColoresApp.acento,
    this.barCount = 4,
  });

  @override
  State<OndaSonidoAnimada> createState() => _OndaSonidoAnimadaState();
}

class _OndaSonidoAnimadaState extends State<OndaSonidoAnimada>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AudioGlobal(),
      builder: (context, _) {
        final bool sonando = AudioGlobal().sonando;

        if (!sonando) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              widget.barCount,
              (index) => Container(
                width: 3,
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.barCount, (index) {
                final double factor =
                    ((index + 1) * 0.25 + _controller.value) % 1.0;
                final double barHeight = 4.0 + (widget.height - 4.0) * factor;

                return Container(
                  width: 3,
                  height: barHeight,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
}
