import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/app_spacing.dart';
import '../../../../../core/domain/value_objects/geo_location.dart';
import '../../../../../core/domain/value_objects/money.dart';
import '../../../../../core/errors/failure.dart';
import '../../../../../core/result/result.dart';
import '../../../../../core/widgets/adaptive_page_body.dart';
import '../../../../../core/widgets/app_page_header.dart';
import '../../../../onboarding/application/onboarding_providers.dart';
import '../../../../onboarding/domain/entities/onboarding_draft.dart';
import '../../../../onboarding/domain/services/location_service.dart';
import '../../application/sports_hub_providers.dart';
import '../../domain/entities/sport_management_requests.dart';
import '../../domain/entities/sports_event.dart';
import '../../domain/services/sport_module_registry.dart';

class CreateSportsEventScreen extends ConsumerStatefulWidget {
  const CreateSportsEventScreen({required this.sportId, super.key});

  final String sportId;

  @override
  ConsumerState<CreateSportsEventScreen> createState() =>
      _CreateSportsEventScreenState();
}

class _CreateSportsEventScreenState
    extends ConsumerState<CreateSportsEventScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _capacity = TextEditingController(text: '20');
  final TextEditingController _price = TextEditingController();
  final TextEditingController _currency = TextEditingController(text: 'ILS');
  SportsEventType _type = SportsEventType.meetup;
  String _minimumLevel = 'beginner';
  String _maximumLevel = 'professional';
  DateTime _start = DateTime.now().add(const Duration(days: 1));
  Duration _duration = const Duration(hours: 1);
  GeoLocation? _location;
  bool _locating = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _capacity.dispose();
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
      appBar: AppBar(title: const Text('Create event')),
      body: AdaptivePageBody(
        slivers: <Widget>[
          AppPageHeader(
            eyebrow: module.title,
            title: 'Create ${module.eventLabel.toLowerCase()}',
            subtitle:
                'Events use trusted attendance, capacity, level, pricing, and moderation controls.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Event title'),
                  maxLength: 120,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1200,
                  validator: _required,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<SportsEventType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Event type'),
                  items: SportsEventType.values
                      .map(
                        (SportsEventType value) =>
                            DropdownMenuItem<SportsEventType>(
                              value: value,
                              child: Text(_humanize(value.name)),
                            ),
                      )
                      .toList(growable: false),
                  onChanged: (SportsEventType? value) =>
                      setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text('${_date(_start)} at ${_time(_start)}'),
                  subtitle: Text('Duration: ${_duration.inMinutes} minutes'),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _pickSchedule,
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.tonalIcon(
                  onPressed: _locating ? null : _captureLocation,
                  icon: Icon(
                    _location == null
                        ? Icons.my_location_rounded
                        : Icons.check_circle_rounded,
                  ),
                  label: Text(
                    _locating
                        ? 'Getting location…'
                        : _location == null
                        ? 'Use current event location'
                        : 'Location captured • ${_location!.locality ?? _location!.countryCode ?? 'coordinates'}',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _minimumLevel,
                        decoration: const InputDecoration(
                          labelText: 'Minimum level',
                        ),
                        items: _levels
                            .map(
                              (String value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(_humanize(value)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (String? value) => setState(
                          () => _minimumLevel = value ?? _minimumLevel,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _maximumLevel,
                        decoration: const InputDecoration(
                          labelText: 'Maximum level',
                        ),
                        items: _levels
                            .map(
                              (String value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(_humanize(value)),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (String? value) => setState(
                          () => _maximumLevel = value ?? _maximumLevel,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _capacity,
                  decoration: const InputDecoration(labelText: 'Capacity'),
                  keyboardType: TextInputType.number,
                  validator: (String? value) {
                    final int? parsed = int.tryParse(value ?? '');
                    return parsed == null || parsed < 2 || parsed > 1000
                        ? 'Choose a capacity from 2 to 1000.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        decoration: const InputDecoration(
                          labelText: 'Price (optional)',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
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
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(
                    action.isLoading ? 'Publishing…' : 'Publish event',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _captureLocation() async {
    setState(() => _locating = true);
    final Result<LocationCapture> result = await ref
        .read(locationServiceProvider)
        .requestCurrentLocation();
    if (!mounted) {
      return;
    }
    result.when<void>(
      success: (LocationCapture capture) {
        setState(() {
          _location = capture.permission == PermissionDecision.granted
              ? capture.location
              : null;
          _locating = false;
        });
        if (_location == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required for a public event.',
              ),
            ),
          );
        }
      },
      failure: (Failure failure) {
        setState(() => _locating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _pickSchedule() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    final int? minutes = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <int>[45, 60, 90, 120, 180]
              .map(
                (int value) => ListTile(
                  title: Text('$value minutes'),
                  onTap: () => Navigator.of(context).pop(value),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _start = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _duration = Duration(minutes: minutes ?? 60);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capture the event location first.')),
      );
      return;
    }
    final double? priceMajor = double.tryParse(_price.text.trim());
    final String? id = await ref
        .read(sportsHubActionControllerProvider.notifier)
        .createEvent(
          CreateSportsEventRequest(
            sportId: widget.sportId,
            type: _type,
            title: _title.text.trim(),
            description: _description.text.trim(),
            startAt: _start.toUtc(),
            endAt: _start.add(_duration).toUtc(),
            timezone: DateTime.now().timeZoneName,
            location: _location!,
            capacity: int.parse(_capacity.text.trim()),
            minimumLevel: _minimumLevel,
            maximumLevel: _maximumLevel,
            price: priceMajor == null || priceMajor <= 0
                ? null
                : Money(
                    amountMinor: (priceMajor * 100).round(),
                    currency: _currency.text.trim().toUpperCase(),
                  ),
          ),
        );
    if (!mounted || id == null) {
      return;
    }
    context.go(AppRoutes.sportEvent(widget.sportId, id));
  }

  static const List<String> _levels = <String>[
    'beginner',
    'intermediate',
    'advanced',
    'professional',
  ];

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
  static String _date(DateTime value) =>
      '${value.day}/${value.month}/${value.year}';
  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
