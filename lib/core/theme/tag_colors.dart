import 'package:flutter/material.dart';
import 'app_colors.dart';

Color tagColor(String tag) {
  return switch (tag) {
    'Food' => const Color(0xFFC2410C),
    'Ticket' => const Color(0xFF1D4ED8),
    'Culture' => const Color(0xFF7E22CE),
    'Nature' => const Color(0xFF15803D),
    'Walk' => const Color(0xFF0F766E),
    'Shops' => const Color(0xFFB45309),
    'View' => const Color(0xFF0369A1),
    'Arrival' => const Color(0xFF4338CA),
    'Flex' => const Color(0xFF4B5563),
    _ => kForest,
  };
}

Color tagTextColor(String tag) {
  return switch (tag) {
    'Food' => const Color(0xFFD84315),
    'Ticket' => const Color(0xFF1565C0),
    'Culture' => const Color(0xFF6A1B9A),
    'Nature' => const Color(0xFF2E7D32),
    'Walk' => kForest,
    'Shops' => const Color(0xFFE65100),
    'View' => const Color(0xFF0277BD),
    'Arrival' => const Color(0xFF283593),
    'Flex' => kMuted,
    _ => kForest,
  };
}

IconData tagIcon(String tag) {
  return switch (tag) {
    'Food' => Icons.restaurant_rounded,
    'Ticket' => Icons.confirmation_number_rounded,
    'Culture' => Icons.museum_rounded,
    'Nature' => Icons.park_rounded,
    'Walk' => Icons.directions_walk_rounded,
    'Shops' => Icons.shopping_bag_rounded,
    'View' => Icons.landscape_rounded,
    'Arrival' => Icons.flight_land_rounded,
    'Flex' => Icons.access_time_rounded,
    _ => Icons.place_rounded,
  };
}
