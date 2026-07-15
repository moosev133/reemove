import 'package:flutter/material.dart';

abstract final class SportIcon {
  static IconData fromKey(String key) => switch (key) {
    'football' => Icons.sports_soccer_rounded,
    'gym' => Icons.fitness_center_rounded,
    'running' => Icons.directions_run_rounded,
    'basketball' => Icons.sports_basketball_rounded,
    'tennis' => Icons.sports_tennis_rounded,
    'swimming' => Icons.pool_rounded,
    'cycling' => Icons.directions_bike_rounded,
    'mma' => Icons.sports_mma_rounded,
    _ => Icons.sports_rounded,
  };
}
