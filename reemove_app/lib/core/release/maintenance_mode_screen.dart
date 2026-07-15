import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MaintenanceModeScreen extends StatelessWidget {
  const MaintenanceModeScreen({
    super.key,
    required this.title,
    required this.message,
    required this.statusUrl,
    required this.supportUrl,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Uri statusUrl;
  final Uri supportUrl;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.construction_rounded, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(
                      statusUrl,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('Service status'),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(
                      supportUrl,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('Support'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
