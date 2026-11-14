import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/models/marketplace_opening_hour.dart';

class MarketplaceOpeningHours extends StatelessWidget {
  const MarketplaceOpeningHours({
    super.key,
    required this.hours,
    required this.timezone,
  });
  final List<MarketplaceOpeningHour> hours;
  final String timezone;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Opening hours', style: Theme.of(context).textTheme.titleLarge),
      Text(
        'Local times \u00b7 $timezone',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
      for (var day = 1; day <= 7; day++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat.EEEE(Localizations.localeOf(context).toString())
                    .format(DateTime(2024, 1, day)),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              if (!hours.any((hour) => hour.dayOfWeek == day))
                const Text('Closed')
              else
                for (final hour in hours.where((hour) => hour.dayOfWeek == day))
                  Text(
                    '${hour.opensAt} \u2013 ${hour.closesAt}${hour.crossesMidnight ? ' (next day)' : ''}',
                  ),
            ],
          ),
        ),
    ],
  );
}
