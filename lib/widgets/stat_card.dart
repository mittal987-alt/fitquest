import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {

  final String title;

  final String value;

  final IconData icon;

  final Color color;

  const StatCard({

    super.key,

    required this.title,

    required this.value,

    required this.icon,

    required this.color,
  });

  @override
  Widget build(BuildContext context) {

    return Container(

      padding:
      const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(22),

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

      child: Column(

        mainAxisAlignment:
        MainAxisAlignment.center,

        children: [

          CircleAvatar(

            radius: 28,

            backgroundColor:
            color.withValues(
                alpha: 0.15),

            child: Icon(

              icon,

              size: 30,

              color: color,
            ),
          ),

          const SizedBox(height: 14),

          Text(

            value,

            style: const TextStyle(

              fontSize: 24,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(

            title,

            style: TextStyle(

              color:
              Colors.grey.shade700,

              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}