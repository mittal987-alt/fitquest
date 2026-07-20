import 'package:flutter/material.dart';

class MovementStatusCard
    extends StatelessWidget {

  final String status;

  final double speed;

  const MovementStatusCard({

    super.key,

    required this.status,

    required this.speed,
  });

  @override
  Widget build(BuildContext context) {

    final colorScheme = Theme.of(context).colorScheme;

    Color statusColor =
        colorScheme.primary;

    IconData statusIcon =
        Icons.directions_walk;

    // =====================
    // STANDING
    // =====================

    if (status.contains(
        "Standing")) {

      statusColor =
          colorScheme.outline;

      statusIcon =
          Icons.accessibility_new;
    }

    // =====================
    // VEHICLE
    // =====================

    if (status.contains(
        "Vehicle")) {

      statusColor =
          colorScheme.error;

      statusIcon =
          Icons.directions_car;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: statusColor.withValues(alpha: 0.1),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${speed.toStringAsFixed(1)} km/h",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}