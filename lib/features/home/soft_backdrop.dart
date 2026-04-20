import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/trip_plan.dart';

class SoftBackdrop extends StatelessWidget {
  const SoftBackdrop({super.key, required this.plan});

  final TripPlan plan;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  kDarkBg,
                  kDarkSurface,
                  kCoral.withValues(alpha: .06),
                  kSky.withValues(alpha: .08),
                ]
              : [
                  kMint,
                  kPaper,
                  kCoral.withValues(alpha: .10),
                  kSky.withValues(alpha: .12),
                ],
        ),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 80, right: 18),
          child: Icon(
            plan.destinations.length > 1
                ? Icons.route_rounded
                : Icons.explore_rounded,
            size: 172,
            color: Colors.white.withValues(alpha: isDark ? .06 : .44),
          ),
        ),
      ),
    );
  }
}
