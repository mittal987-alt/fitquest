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

    Color statusColor =
        Colors.green;

    IconData statusIcon =
        Icons.directions_walk;

    // =====================
    // STANDING
    // =====================

    if (status.contains(
        "Standing")) {

      statusColor =
          Colors.blueGrey;

      statusIcon =
          Icons.accessibility_new;
    }

    // =====================
    // VEHICLE
    // =====================

    if (status.contains(
        "Vehicle")) {

      statusColor =
          Colors.red;

      statusIcon =
          Icons.directions_car;
    }

    return Container(

      margin:
      const EdgeInsets.all(16),

      padding:
      const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(24),

        boxShadow: [

          BoxShadow(

            color:
            Colors.black12,

            blurRadius: 10,

            offset:
            const Offset(0, 4),
          ),
        ],
      ),

      child: Row(

        children: [

          CircleAvatar(

            radius: 30,

            backgroundColor:
            statusColor
                .withValues(
                alpha: 0.15),

            child: Icon(

              statusIcon,

              color: statusColor,

              size: 30,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(

            child: Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                Text(

                  status,

                  style:
                  TextStyle(

                    fontSize: 22,

                    fontWeight:
                    FontWeight.bold,

                    color:
                    statusColor,
                  ),
                ),

                const SizedBox(
                    height: 6),

                Text(

                  "${speed.toStringAsFixed(1)} km/h",

                  style: TextStyle(

                    color:
                    Colors.grey.shade700,

                    fontSize: 16,
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