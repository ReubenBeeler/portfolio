import 'package:flutter/material.dart';

class MyCard extends StatelessWidget {
  final Widget child;
  const MyCard({super.key, required this.child});

  // No BackdropFilter. It snapshots everything painted behind it, blurs it in
  // two passes and composites the result, every frame, and it does that whether
  // the backdrop is a photograph or a flat colour. On an Intel UHD at 3774x2041
  // it cost 136 long frames against 17 without it, which was more than the
  // whole rest of the page combined.

  @override
  Widget build(BuildContext context) {
    return Container(
      // constraints: const BoxConstraints(minHeight: 200),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
