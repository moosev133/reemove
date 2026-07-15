import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_page_header.dart';

class DiscoverCategoryScreen extends StatelessWidget {
  const DiscoverCategoryScreen({required this.category, super.key});

  final String category;

  @override
  Widget build(BuildContext context) {
    final String title = category.isEmpty
        ? 'Explore'
        : '${category[0].toUpperCase()}${category.substring(1)}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: AdaptivePageBody(
        slivers: <Widget>[
          AppPageHeader(
            title: title,
            subtitle:
                'Browse $title selected for your sports and discovery preferences.',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppEmptyState(
            icon: Icons.filter_alt_outlined,
            title: 'No matching $title right now',
            message:
                'Adjusting your location and discovery preferences may reveal more results.',
          ),
        ],
      ),
    );
  }
}
