import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_community.dart';
import '../../domain/entities/sport_management_requests.dart';
import '../../domain/services/sport_module_registry.dart';

class CreateSportCommunityScreen extends ConsumerStatefulWidget {
  const CreateSportCommunityScreen({required this.sportId, super.key});

  final String sportId;

  @override
  ConsumerState<CreateSportCommunityScreen> createState() =>
      _CreateSportCommunityScreenState();
}

class _CreateSportCommunityScreenState
    extends ConsumerState<CreateSportCommunityScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _country = TextEditingController(text: 'IL');
  final TextEditingController _capacity = TextEditingController(text: '30');
  final TextEditingController _tags = TextEditingController();
  final TextEditingController _pricing = TextEditingController();
  SportCommunityType _type = SportCommunityType.socialGroup;
  SportCommunityJoinPolicy _joinPolicy = SportCommunityJoinPolicy.open;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _city.dispose();
    _country.dispose();
    _capacity.dispose();
    _tags.dispose();
    _pricing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SportModuleConfig module = SportModuleRegistry.resolve(
      widget.sportId,
    );
    final AsyncValue<void> action = ref.watch(
      sportsHubActionControllerProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Create community')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: module.title,
            title: 'Create ${module.communityLabel.toLowerCase()}',
            subtitle:
                'Owners manage membership, capacity, identity, and community standards.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Community name',
                  ),
                  maxLength: 80,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 800,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<SportCommunityType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Community type',
                  ),
                  items: SportCommunityType.values
                      .map(
                        (SportCommunityType value) =>
                            DropdownMenuItem<SportCommunityType>(
                              value: value,
                              child: Text(_humanize(value.name)),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (SportCommunityType? value) =>
                      setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<SportCommunityJoinPolicy>(
                  initialValue: _joinPolicy,
                  decoration: const InputDecoration(labelText: 'Join policy'),
                  items: SportCommunityJoinPolicy.values
                      .map(
                        (SportCommunityJoinPolicy value) =>
                            DropdownMenuItem<SportCommunityJoinPolicy>(
                              value: value,
                              child: Text(_humanize(value.name)),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (SportCommunityJoinPolicy? value) =>
                      setState(() => _joinPolicy = value ?? _joinPolicy),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _city,
                        decoration: const InputDecoration(labelText: 'City'),
                        maxLength: 80,
                        validator: _required,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        controller: _country,
                        decoration: const InputDecoration(labelText: 'Country'),
                        maxLength: 2,
                        textCapitalization: TextCapitalization.characters,
                        validator: _required,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _capacity,
                  decoration: const InputDecoration(
                    labelText: 'Maximum members',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (String? value) {
                    final int? parsed = int.tryParse(value ?? '');
                    if (parsed == null || parsed < 2 || parsed > 500) {
                      return 'Choose a capacity from 2 to 500.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _tags,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'competitive, beginners, weekend',
                  ),
                  maxLength: 200,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _pricing,
                  decoration: const InputDecoration(
                    labelText: 'Pricing or dues (optional)',
                    hintText: 'Free, 50 ILS monthly, pay per session',
                  ),
                  maxLength: 120,
                ),
                if (action.hasError) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    action.error.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: action.isLoading ? null : _submit,
                  icon: const Icon(Icons.groups_rounded),
                  label: Text(
                    action.isLoading ? 'Creating…' : 'Create community',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final String? id = await ref
        .read(sportsHubActionControllerProvider.notifier)
        .createCommunity(
          CreateSportCommunityRequest(
            sportId: widget.sportId,
            name: _name.text.trim(),
            description: _description.text.trim(),
            type: _type,
            joinPolicy: _joinPolicy,
            capacity: int.parse(_capacity.text.trim()),
            tags: _tags.text
                .split(',')
                .map((String item) => item.trim())
                .where((String item) => item.isNotEmpty)
                .toList(growable: false),
            city: _city.text.trim(),
            countryCode: _country.text.trim().toUpperCase(),
            pricingText: _pricing.text.trim().isEmpty
                ? null
                : _pricing.text.trim(),
          ),
        );
    if (!mounted || id == null) {
      return;
    }
    context.go(AppRoutes.sportCommunity(widget.sportId, id));
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required.' : null;

  static String _humanize(String value) => value
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (Match match) => '${match[1]} ${match[2]}',
      )
      .replaceFirstMapped(
        RegExp(r'^.'),
        (Match match) => match[0]!.toUpperCase(),
      );
}
