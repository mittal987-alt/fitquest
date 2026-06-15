import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/player_model.dart';

import '../services/firebase_service.dart';

import 'login_screen.dart';

class ProfileScreen
    extends StatelessWidget {

  const ProfileScreen(
      {super.key});

  @override
  Widget build(BuildContext context) {

    final user =
        FirebaseAuth
            .instance
            .currentUser;

    if (user == null) {

      return const Scaffold(

        body: Center(

          child: Text(
              "User Not Logged In"),
        ),
      );
    }

    return StreamBuilder<
        PlayerModel?>(

      stream:
      FirebaseService()
          .getPlayerStream(
          user.uid),

      builder:
          (context, snapshot) {

        // LOADING
        if (snapshot
            .connectionState ==
            ConnectionState
                .waiting) {

          return const Scaffold(

            body: Center(

              child:
              CircularProgressIndicator(),
            ),
          );
        }

        // NO DATA
        if (!snapshot.hasData ||

            snapshot.data ==
                null) {

          return const Scaffold(

            body: Center(

              child:
              Text(
                  "Player Not Found"),
            ),
          );
        }

        final player =
        snapshot.data!;

        return Scaffold(

          backgroundColor:
          Colors.grey
              .shade100,

          appBar: AppBar(

            title:
            const Text(
                "Profile"),

            centerTitle:
            true,
          ),

          body:
          SingleChildScrollView(

            padding:
            const EdgeInsets
                .all(16),

            child: Column(

              children: [

                // =====================
                // PROFILE HEADER
                // =====================

                Container(

                  width:
                  double.infinity,

                  padding:
                  const EdgeInsets
                      .all(24),

                  decoration:
                  BoxDecoration(

                    gradient:
                    const LinearGradient(

                      colors: [

                        Colors.purple,

                        Colors
                            .deepPurple,
                      ],
                    ),

                    borderRadius:
                    BorderRadius.circular(
                        28),
                  ),

                  child: Column(

                    children: [

                      const CircleAvatar(

                        radius:
                        50,

                        backgroundColor:
                        Colors
                            .white24,

                        child: Icon(

                          Icons
                              .person,

                          size:
                          60,

                          color:
                          Colors
                              .white,
                        ),
                      ),

                      const SizedBox(
                          height:
                          16),

                      Text(

                        player.name,

                        style:
                        const TextStyle(

                          color: Colors
                              .white,

                          fontSize:
                          24,

                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),

                      const SizedBox(
                          height:
                          8),

                      Text(

                        player.email,

                        style:
                        const TextStyle(

                          color: Colors
                              .white70,

                          fontSize:
                          16,
                        ),
                      ),

                      const SizedBox(
                          height:
                          12),

                      Text(

                        "Level ${player.level} Explorer",

                        style:
                        const TextStyle(

                          color: Colors
                              .white,

                          fontSize:
                          18,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                    height: 24),

                // =====================
                // STATS
                // =====================

                Row(

                  children: [

                    Expanded(

                      child:
                      profileStat(

                        title:
                        "Steps",

                        value: player
                            .totalSteps
                            .toString(),

                        icon: Icons
                            .directions_walk,

                        color:
                        Colors
                            .blue,
                      ),
                    ),

                    const SizedBox(
                        width:
                        12),

                    Expanded(

                      child:
                      profileStat(

                        title:
                        "Land",

                        value: player
                            .totalLand
                            .toString(),

                        icon: Icons
                            .public,

                        color:
                        Colors
                            .green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                    height: 12),

                Row(

                  children: [

                    Expanded(

                      child:
                      profileStat(

                        title:
                        "Level",

                        value: player
                            .level
                            .toString(),

                        icon:
                        Icons
                            .star,

                        color:
                        Colors
                            .orange,
                      ),
                    ),

                    const SizedBox(
                        width:
                        12),

                    Expanded(

                      child:
                      profileStat(

                        title:
                        "Trust",

                        value: player
                            .trustScore
                            .toString(),

                        icon: Icons
                            .verified,

                        color:
                        Colors
                            .purple,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                    height: 12),

                Row(

                  children: [

                    Expanded(

                      child:
                      profileStat(

                        title:
                        "XP",

                        value: player
                            .xp
                            .toString(),

                        icon: Icons
                            .flash_on,

                        color:
                        Colors
                            .amber,
                      ),
                    ),

                    const SizedBox(
                        width:
                        12),

                    Expanded(

                      child:
                      profileStat(

                        title:
                        "Team",

                        value:
                        player
                            .team,

                        icon:
                        Icons
                            .groups,

                        color:
                        Colors
                            .teal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                    height: 30),

                // =====================
                // ACHIEVEMENTS
                // =====================

                Container(

                  width:
                  double.infinity,

                  padding:
                  const EdgeInsets
                      .all(20),

                  decoration:
                  BoxDecoration(

                    color:
                    Colors
                        .white,

                    borderRadius:
                    BorderRadius.circular(
                        24),

                    boxShadow: [

                      BoxShadow(

                        color: Colors
                            .black12,

                        blurRadius:
                        10,
                      ),
                    ],
                  ),

                  child: Column(

                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                    children: [

                      const Text(

                        "Achievements",

                        style:
                        TextStyle(

                          fontSize:
                          22,

                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),

                      const SizedBox(
                          height:
                          20),

                      achievementTile(
                        icon: Icons.emoji_events,
                        title: "Walker",
                        subtitle: "${player.totalSteps} total steps",
                        isUnlocked: player.totalSteps >= 1000,
                      ),
                      achievementTile(
                        icon: Icons.public,
                        title: "Territory",
                        subtitle: "${player.totalLand} lands captured",
                        isUnlocked: player.totalLand >= 10,
                      ),
                      achievementTile(
                        icon: Icons.shield,
                        title: "Trust Score",
                        subtitle: "${player.trustScore}/100 trusted",
                        isUnlocked: player.trustScore >= 90,
                      ),
                      achievementTile(
                        icon: Icons.flash_on,
                        title: "XP Veteran",
                        subtitle: "${player.xp}/5000 XP reached",
                        isUnlocked: player.xp >= 5000,
                      ),
                    ],
                  ),
                ),

                const SizedBox(
                    height: 30),

                // =====================
                // LOGOUT
                // =====================

                SizedBox(

                  width:
                  double.infinity,

                  child:
                  ElevatedButton.icon(

                    style:
                    ElevatedButton
                        .styleFrom(

                      backgroundColor:
                      Colors.red,

                      padding:
                      const EdgeInsets.symmetric(
                        vertical:
                        18,
                      ),

                      shape:
                      RoundedRectangleBorder(

                        borderRadius:
                        BorderRadius.circular(
                            18),
                      ),
                    ),

                    onPressed:
                        () async {

                      await FirebaseAuth
                          .instance
                          .signOut();

                      if (context
                          .mounted) {

                        Navigator
                            .pushReplacement(

                          context,

                          MaterialPageRoute(

                            builder:
                                (_) =>
                            const LoginScreen(),
                          ),
                        );
                      }
                    },

                    icon:
                    const Icon(
                        Icons
                            .logout),

                    label:
                    const Text(
                        "Logout"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================
  // PROFILE STAT
  // =========================

  Widget profileStat({

    required String title,

    required String value,

    required IconData icon,

    required Color color,
  }) {

    return Container(

      padding:
      const EdgeInsets
          .all(18),

      decoration:
      BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(
            22),

        boxShadow: [

          BoxShadow(

            color:
            Colors.black12,

            blurRadius: 10,
          ),
        ],
      ),

      child: Column(

        children: [

          CircleAvatar(

            radius: 28,

            backgroundColor:
            color.withValues(
                alpha: 0.15),

            child: Icon(

              icon,

              color: color,

              size: 28,
            ),
          ),

          const SizedBox(
              height: 12),

          Text(

            value,

            style:
            const TextStyle(

              fontSize: 20,

              fontWeight:
              FontWeight.bold,
            ),
          ),

          const SizedBox(
              height: 8),

          Text(title),
        ],
      ),
    );
  }

  // =========================
  // ACHIEVEMENT TILE
  // =========================

  Widget achievementTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isUnlocked,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isUnlocked
            ? Colors.orange.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        child: Icon(
          icon,
          color: isUnlocked ? Colors.orange : Colors.grey,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isUnlocked ? Colors.black : Colors.grey,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: isUnlocked ? Colors.black87 : Colors.grey,
        ),
      ),
      trailing: isUnlocked
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.lock, color: Colors.grey, size: 20),
    );
  }
}