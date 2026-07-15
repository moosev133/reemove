import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({
    super.key,
    required this.storeUrl,
    required this.supportUrl,
  });

  final Uri storeUrl;
  final Uri supportUrl;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.system_update_rounded, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    'Update ReeMove',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A newer secure version is required to continue.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => launchUrl(
                      storeUrl,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('Open store'),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(
                      supportUrl,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text('Get help'),
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
