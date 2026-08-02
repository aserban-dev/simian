/// The stage timeline above the map (T101).
///
/// All four stages with their timestamps, and the current one marked. Every stage is shown,
/// including the ones still ahead: a timeline that only lists what has happened tells the user
/// nothing about what comes next, and "what comes next" is the question the screen exists to
/// answer.
///
/// Principle VII: the current stage is marked by an icon *and* a label, never by colour alone.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/parcel_position.dart';

class StageTimeline extends StatelessWidget {
  const StageTimeline({
    required this.tracking,
    required this.now,
    super.key,
  });

  final DeliveryTracking tracking;
  final DateTime now;

  static const String currentSuffix = 'now';

  DateTime _timestampFor(DeliveryStage stage) => switch (stage) {
        DeliveryStage.processing => tracking.processingAt,
        DeliveryStage.shipped => tracking.shippedAt,
        DeliveryStage.outForDelivery => tracking.outForDeliveryAt,
        DeliveryStage.delivered => tracking.deliveredAt,
      };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DeliveryStage current = tracking.stageAt(now);
    final DateFormat format = DateFormat.MMMEd().add_jm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final DeliveryStage stage in DeliveryStage.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  stage.index < current.index
                      ? Icons.check_circle
                      : stage == current
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                  size: 20,
                  color: stage.index <= current.index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                ),
                const SizedBox(width: 12),
                // Expanded, not a fixed width: at a large text scale these labels wrap, and the
                // row has to grow rather than clip (FR-067).
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        stage == current
                            ? '${stage.label} — ${StageTimeline.currentSuffix}'
                            : stage.label,
                        style: stage == current
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.bodyMedium,
                      ),
                      Text(
                        format.format(_timestampFor(stage).toLocal()),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
