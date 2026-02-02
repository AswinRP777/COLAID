import 'package:flutter/material.dart';

class BottomSliderCompare extends StatefulWidget {
  final Widget before;
  final Widget after;

  const BottomSliderCompare({
    super.key,
    required this.before,
    required this.after,
  });

  @override
  State<BottomSliderCompare> createState() => _BottomSliderCompareState();
}

class _BottomSliderCompareState extends State<BottomSliderCompare> {
  double value = 0.0; // 0 = only AFTER, 1 = full BEFORE

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Column(
          children: [
            // IMAGE AREA
            Expanded(
              child: Stack(
                children: [
                  // AFTER image (full background, expanded)
                  Positioned.fill(child: SizedBox.expand(child: widget.after)),

                  // BEFORE image (clips from left based on slider value)
                  Positioned.fill(
                    child: ClipRect(
                      clipper: _LeftClipper(value, width),
                      child: SizedBox.expand(child: widget.before),
                    ),
                  ),

                  // White divider line
                  Positioned(
                    left: width * value - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.white),
                  ),

                  // "Original" label - top left
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Original',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // "Enhanced" label - top right
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Enhanced',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // BOTTOM SLIDER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Slider(
                value: value,
                min: 0,
                max: 1,
                divisions: 100,
                activeColor: Colors.white,
                inactiveColor: Colors.white38,
                onChanged: (v) {
                  setState(() => value = v);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// Custom clipper that clips from the left side based on fraction
class _LeftClipper extends CustomClipper<Rect> {
  final double fraction;
  final double containerWidth;

  _LeftClipper(this.fraction, this.containerWidth);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(0, 0, containerWidth * fraction, size.height);
  }

  @override
  bool shouldReclip(_LeftClipper oldClipper) =>
      oldClipper.fraction != fraction ||
      oldClipper.containerWidth != containerWidth;
}
