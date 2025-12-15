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
                  // BEFORE image (anchored to LEFT, opens from left)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          widthFactor: value,
                          child: widget.before,
                        ),
                      ),
                    ),
                  ),

                  // AFTER image (anchored to RIGHT, closes to right)
                  Positioned.fill(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.centerRight,
                          widthFactor: 1.0 - value,
                          child: widget.after,
                        ),
                      ),
                    ),
                  ),

                  // Divider line (moves left → right)
                  Positioned(
                    left: width * value - 1,
                    top: 40,
                    bottom: 40,
                    child: Container(
                      width: 2,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            // BOTTOM SLIDER
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
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
