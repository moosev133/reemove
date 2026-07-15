import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_page_body.dart';
import '../../../../core/widgets/app_empty_state.dart';

class DiscoverSearchScreen extends StatefulWidget {
  const DiscoverSearchScreen({super.key});

  @override
  State<DiscoverSearchScreen> createState() => _DiscoverSearchScreenState();
}

class _DiscoverSearchScreenState extends State<DiscoverSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SearchBar(
          controller: _controller,
          autoFocus: true,
          hintText: 'People, places, events…',
          leading: const Icon(Icons.search_rounded),
          trailing: <Widget>[
            if (_query.isNotEmpty)
              IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _controller.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
          ],
          onChanged: (String value) => setState(() => _query = value.trim()),
        ),
      ),
      body: AdaptivePageBody(
        slivers: <Widget>[
          const SizedBox(height: AppSpacing.md),
          AppEmptyState(
            icon: _query.isEmpty
                ? Icons.search_rounded
                : Icons.manage_search_rounded,
            title: _query.isEmpty ? 'Search all of ReeMove' : 'No results yet',
            message: _query.isEmpty
                ? 'Try an athlete name, sport, gym, club, route, event, or challenge.'
                : 'No accessible result currently matches “$_query”.',
          ),
        ],
      ),
    );
  }
}
