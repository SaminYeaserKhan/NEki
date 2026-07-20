import 'package:flutter/material.dart';

/// Smoothly rolls digits when a numeric value changes.
///
/// ```dart
/// AnimatedCounter(
///   value: 42,
///   style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
/// )
/// ```
class AnimatedCounter extends StatelessWidget {
  /// The numeric value to display.
  final int value;

  /// Text style applied to each digit.
  final TextStyle? style;

  /// Duration of the rolling animation per digit.
  final Duration duration;

  /// Optional prefix displayed before the number (e.g. a minus sign).
  final String prefix;

  /// Optional suffix displayed after the number (e.g. a unit label).
  final String suffix;

  /// Minimum number of digits to display (zero-pads from left).
  final int minDigits;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.style,
    this.duration = const Duration(milliseconds: 500),
    this.prefix = '',
    this.suffix = '',
    this.minDigits = 1,
  });

  @override
  Widget build(BuildContext context) {
    final digits = value.toString().padLeft(minDigits, '0');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (prefix.isNotEmpty) Text(prefix, style: style),
        for (int i = 0; i < digits.length; i++)
          _RollingDigit(
            digit: int.parse(digits[i]),
            style: style ?? Theme.of(context).textTheme.headlineMedium!,
            duration: duration,
          ),
        if (suffix.isNotEmpty) Text(suffix, style: style),
      ],
    );
  }
}

class _RollingDigit extends StatefulWidget {
  final int digit;
  final TextStyle style;
  final Duration duration;

  const _RollingDigit({
    required this.digit,
    required this.style,
    required this.duration,
  });

  @override
  State<_RollingDigit> createState() => _RollingDigitState();
}

class _RollingDigitState extends State<_RollingDigit>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideOut;
  late Animation<Offset> _slideIn;
  late Animation<double> _fadeOut;
  late Animation<double> _fadeIn;

  int _currentDigit = 0;
  int _nextDigit = 0;

  @override
  void initState() {
    super.initState();
    _currentDigit = widget.digit;
    _nextDigit = widget.digit;

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInCubic,
    ));

    _slideIn = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5),
      ),
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0),
      ),
    );
  }

  @override
  void didUpdateWidget(_RollingDigit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.digit != widget.digit) {
      _currentDigit = oldWidget.digit;
      _nextDigit = widget.digit;
      _controller.forward(from: 0);
      _controller.addStatusListener(_onAnimationDone);
    }
  }

  void _onAnimationDone(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _currentDigit = _nextDigit;
      _controller.removeStatusListener(_onAnimationDone);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Measure the width of a single digit to keep layout stable.
    final textPainter = TextPainter(
      text: TextSpan(text: '0', style: widget.style),
      textDirection: TextDirection.ltr,
    )..layout();

    final digitWidth = textPainter.width;
    final digitHeight = textPainter.height;

    return SizedBox(
      width: digitWidth,
      height: digitHeight,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                // Outgoing digit (slides up, fades out)
                SlideTransition(
                  position: _slideOut,
                  child: Opacity(
                    opacity: _fadeOut.value,
                    child: SizedBox(
                      width: digitWidth,
                      child: Text(
                        '$_currentDigit',
                        style: widget.style,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                // Incoming digit (slides up from below, fades in)
                SlideTransition(
                  position: _slideIn,
                  child: Opacity(
                    opacity: _fadeIn.value,
                    child: SizedBox(
                      width: digitWidth,
                      child: Text(
                        '$_nextDigit',
                        style: widget.style,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
