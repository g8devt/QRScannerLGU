import 'package:flutter/material.dart';

/// Shared label/value section card — replaces the three independently
/// reimplemented `_SectionCard`/`_ReadOnlySection` widgets previously in
/// service_details_page.dart, cvl_lookup_page.dart, and
/// cvl_edit_page.dart (which had drifted to two different label column
/// widths, 120 and 140, and two different label text styles). A [rows]
/// entry is expected to already be conditionally included by the caller
/// (e.g. `if (record.email.isNotEmpty) 'Email': record.email`) — this
/// widget itself only decides whether to render at all (an empty map
/// renders nothing, matching all three predecessors' behavior).
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  static const _labelWidth = 130.0;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _labelWidth,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Text(entry.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
