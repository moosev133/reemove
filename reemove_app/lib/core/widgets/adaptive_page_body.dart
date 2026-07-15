import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../responsive/app_breakpoints.dart';

class AdaptivePageBody extends StatelessWidget {
  const AdaptivePageBody({
    required this.slivers,
    super.key,
    this.controller,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.restorationId,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xxl,
    ),
  });

  final List<Widget> slivers;
  final ScrollController? controller;
  final double maxWidth;
  final String? restorationId;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      restorationId: restorationId,
      slivers: <Widget>[
        SliverPadding(
          padding: padding,
          sliver: SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: slivers,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
