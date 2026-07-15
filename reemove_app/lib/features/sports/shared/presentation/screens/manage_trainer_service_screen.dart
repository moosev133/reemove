import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/domain/value_objects/money.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_management_requests.dart';
import '../../domain/entities/sport_trainer.dart';
import '../../domain/services/sport_module_registry.dart';

class ManageTrainerServiceScreen extends ConsumerStatefulWidget {
  const ManageTrainerServiceScreen({required this.sportId, super.key});

  final String sportId;

  @override
  ConsumerState<ManageTrainerServiceScreen> createState() =>
      _ManageTrainerServiceScreenState();
}

class _ManageTrainerServiceScreenState
    extends ConsumerState<ManageTrainerServiceScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _duration = TextEditingController(text: '60');
  final TextEditingController _price = TextEditingController();
  final TextEditingController _currency = TextEditingController(text: 'ILS');
  TrainerServiceType _type = TrainerServiceType.personalTraining;
  TrainerDeliveryMode _deliveryMode = TrainerDeliveryMode.inPerson;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _duration.dispose();
    _price.dispose();
    _currency.dispose();
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
      appBar: AppBar(title: const Text('Trainer service')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: module.title,
            title: 'Publish a trainer service',
            subtitle:
                'Only eligible trainer profiles can publish. Verification and professional details are checked server-side.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Service title'),
                  maxLength: 100,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 700,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<TrainerServiceType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Service type'),
                  items: TrainerServiceType.values
                      .map(
                        (TrainerServiceType value) =>
                            DropdownMenuItem<TrainerServiceType>(
                              value: value,
                              child: Text(_humanize(value.name)),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (TrainerServiceType? value) =>
                      setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<TrainerDeliveryMode>(
                  initialValue: _deliveryMode,
                  decoration: const InputDecoration(labelText: 'Delivery mode'),
                  items: TrainerDeliveryMode.values
                      .map(
                        (TrainerDeliveryMode value) =>
                            DropdownMenuItem<TrainerDeliveryMode>(
                              value: value,
                              child: Text(_humanize(value.name)),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (TrainerDeliveryMode? value) =>
                      setState(() => _deliveryMode = value ?? _deliveryMode),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _duration,
                  decoration: const InputDecoration(
                    labelText: 'Duration in minutes',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (String? value) {
                    final int? parsed = int.tryParse(value ?? '');
                    return parsed == null || parsed < 15 || parsed > 480
                        ? 'Choose a duration from 15 to 480 minutes.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        decoration: const InputDecoration(labelText: 'Price'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (String? value) {
                          final double? parsed = double.tryParse(value ?? '');
                          return parsed == null ||
                                  parsed <= 0 ||
                                  parsed > 100000
                              ? 'Enter a valid positive price.'
                              : null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    SizedBox(
                      width: 110,
                      child: TextFormField(
                        controller: _currency,
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                        maxLength: 3,
                        textCapitalization: TextCapitalization.characters,
                        validator: _required,
                      ),
                    ),
                  ],
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
                  icon: const Icon(Icons.publish_rounded),
                  label: Text(
                    action.isLoading ? 'Publishing…' : 'Publish service',
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
        .upsertTrainerService(
          UpsertTrainerServiceRequest(
            sportId: widget.sportId,
            title: _title.text.trim(),
            description: _description.text.trim(),
            type: _type,
            deliveryMode: _deliveryMode,
            durationMinutes: int.parse(_duration.text.trim()),
            price: Money(
              amountMinor: (double.parse(_price.text.trim()) * 100).round(),
              currency: _currency.text.trim().toUpperCase(),
            ),
          ),
        );
    if (!mounted || id == null) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Trainer service published.')));
    context.go(AppRoutes.sportTrainers(widget.sportId));
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
