import 'package:flutter/material.dart';

import '../../../domain/models/campus/navigation_fix.dart';

class CampusLocationStatus extends StatelessWidget {
  const CampusLocationStatus({
    super.key,
    required this.access,
    required this.onRetry,
    required this.onSettings,
    this.accuracy,
    this.simulated = false,
  });
  final LocationAccess access;
  final VoidCallback onRetry, onSettings;
  final double? accuracy;
  final bool simulated;
  @override
  Widget build(BuildContext context) {
    if (simulated || access == LocationAccess.idle) {
      return const SizedBox.shrink();
    }
    final message = switch (access) {
      LocationAccess.acquiring => 'Acquiring your location…',
      LocationAccess.ready =>
        accuracy == null
            ? 'Location ready'
            : 'Location accuracy ±${accuracy!.round()} m',
      LocationAccess.denied => 'Location permission denied.',
      LocationAccess.permanentlyDenied => 'Allow location access in Settings.',
      LocationAccess.disabled => 'Location services are off.',
      _ => 'Location unavailable. Try again outdoors.',
    };
    final settings =
        access == LocationAccess.permanentlyDenied ||
        access == LocationAccess.disabled;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: Theme.of(context).textTheme.bodySmall),
            if (access != LocationAccess.acquiring &&
                access != LocationAccess.ready)
              TextButton(
                onPressed: settings ? onSettings : onRetry,
                child: Text(settings ? 'Open settings' : 'Retry location'),
              ),
          ],
        ),
      ),
    );
  }
}
