import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ai_providers.dart';
import '../../domain/entities/ai_models.dart';
import '../../domain/repositories/ai_repository.dart';
import '../widgets/ai_result_view.dart';

enum AiFormKind {
  coach,
  workout,
  nutrition,
  matchmaker,
  challenge,
  content,
  trainerInsights,
}

class AiModuleFormScreen extends ConsumerStatefulWidget {
  const AiModuleFormScreen({
    super.key,
    required this.kind,
    required this.title,
  });

  final AiFormKind kind;
  final String title;

  @override
  ConsumerState<AiModuleFormScreen> createState() => _AiModuleFormScreenState();
}

class _AiModuleFormScreenState extends ConsumerState<AiModuleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _primary = TextEditingController();
  final _secondary = TextEditingController();
  final _tertiary = TextEditingController();
  final _candidateIds = TextEditingController();
  int _days = 3;
  int _minutes = 45;

  @override
  void dispose() {
    _primary.dispose();
    _secondary.dispose();
    _tertiary.dispose();
    _candidateIds.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    await ref.read(aiActionControllerProvider.notifier).execute(_action);
  }

  Future<AiGeneratedResult> _action(AiRepository repository) {
    return switch (widget.kind) {
      AiFormKind.coach => repository.askCoach(message: _primary.text),
      AiFormKind.workout => repository.generateWorkout(
        sport: _primary.text,
        goal: _secondary.text,
        level: _tertiary.text,
        daysPerWeek: _days,
        sessionMinutes: _minutes,
      ),
      AiFormKind.nutrition => repository.generateNutritionGuidance(
        sport: _primary.text,
        goal: _secondary.text,
        activityLevel: _tertiary.text,
      ),
      AiFormKind.matchmaker => repository.rankMatches(
        sport: _primary.text,
        candidateIds: _candidateIds.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        preferences: _secondary.text,
      ),
      AiFormKind.challenge => repository.generateChallenge(
        sport: _primary.text,
        level: _secondary.text,
        durationDays: _days,
        equipment: _tertiary.text,
      ),
      AiFormKind.content => repository.createContent(
        sourceText: _primary.text,
        tone: _secondary.text,
        platform: _tertiary.text,
      ),
      AiFormKind.trainerInsights => repository.getTrainerInsights(
        period: _primary.text,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiActionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(children: _fieldsForKind()),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.isLoading ? null : _submit,
              icon: state.isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(state.isLoading ? 'Generating…' : 'Generate'),
            ),
            state.when(
              data: (result) => result == null
                  ? const SizedBox.shrink()
                  : AiResultView(result: result),
              loading: () => const SizedBox.shrink(),
              error: (error, _) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  error.toString(),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fieldsForKind() {
    Widget field(
      TextEditingController controller,
      String label, {
      int maxLines = 1,
      bool required = true,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: required
              ? (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null
              : null,
        ),
      );
    }

    Widget slider(
      String label,
      int value,
      int min,
      int max,
      ValueChanged<int> onChanged,
    ) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label: $value'),
            Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              label: '$value',
              onChanged: (next) => setState(() => onChanged(next.round())),
            ),
          ],
        ),
      );
    }

    return switch (widget.kind) {
      AiFormKind.coach => [field(_primary, 'Ask the AI Coach', maxLines: 5)],
      AiFormKind.workout => [
        field(_primary, 'Sport'),
        field(_secondary, 'Goal'),
        field(_tertiary, 'Level'),
        slider('Days per week', _days, 1, 6, (v) => _days = v),
        slider('Session minutes', _minutes, 20, 90, (v) => _minutes = v),
      ],
      AiFormKind.nutrition => [
        field(_primary, 'Sport'),
        field(_secondary, 'Goal'),
        field(_tertiary, 'Activity level'),
      ],
      AiFormKind.matchmaker => [
        field(_primary, 'Sport'),
        field(_candidateIds, 'Candidate user IDs, comma-separated'),
        field(_secondary, 'Preferences', maxLines: 3, required: false),
      ],
      AiFormKind.challenge => [
        field(_primary, 'Sport'),
        field(_secondary, 'Level'),
        field(_tertiary, 'Available equipment', required: false),
        slider('Duration days', _days, 1, 30, (v) => _days = v),
      ],
      AiFormKind.content => [
        field(_primary, 'What happened?', maxLines: 5),
        field(_secondary, 'Tone'),
        field(_tertiary, 'Platform'),
      ],
      AiFormKind.trainerInsights => [
        field(_primary, 'Period, for example: last_30_days'),
      ],
    };
  }
}
