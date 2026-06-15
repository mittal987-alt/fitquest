import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/player_model.dart';

import '../services/firebase_service.dart';

class TeamMembersScreen
    extends StatelessWidget {

  final String teamName;
  final String teamId;
  final String leaderId;

  const TeamMembersScreen({
    super.key,
    required this.teamName,
    required this.teamId,
    required this.leaderId,
  });

  @override
  Widget build(BuildContext context) {
    final currentUid =
        FirebaseAuth
            .instance
            .currentUser!
            .uid;

    final bool isLeader =
        currentUid == leaderId;

    return Scaffold(

      backgroundColor:
      Colors.grey.shade100,

      appBar: AppBar(

        title:
        Text(
            "$teamName Members"),

        centerTitle: true,
      ),

      body:
      StreamBuilder<QuerySnapshot>(

        stream:
        FirebaseFirestore
            .instance

            .collection(
            "players")

            .where(
          "team",
          isEqualTo:
          teamName,
        )

            .snapshots(),

        builder:
            (context, snapshot) {

          if (snapshot
              .connectionState ==
              ConnectionState
                  .waiting) {

            return const Center(

              child:
              CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData ||

              snapshot
                  .data!
                  .docs
                  .isEmpty) {

            return const Center(

              child: Text(
                "No Members Found",
              ),
            );
          }

          List<PlayerModel>
          members =

          snapshot
              .data!
              .docs

              .map((doc) {

            return PlayerModel
                .fromMap(

              doc.data()
              as Map<String,
                  dynamic>,
            );
          }).toList();

          // SORT BY STEPS

          members.sort(

                (a, b) => b
                .totalSteps
                .compareTo(
              a.totalSteps,
            ),
          );

          return ListView.builder(

            padding:
            const EdgeInsets
                .all(16),

            itemCount:
            members.length,

            itemBuilder:
                (context, index) {

              final player =
              members[index];

              final bool
              playerIsLeader =

                  player.uid ==
                      leaderId;

              return Container(

                margin:
                const EdgeInsets
                    .only(
                  bottom: 14,
                ),

                padding:
                const EdgeInsets
                    .all(18),

                decoration:
                BoxDecoration(

                  color:
                  Colors.white,

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

                  children: [

                    Row(

                      children: [

                        // RANK
                        CircleAvatar(

                          radius: 22,

                          backgroundColor:
                          Colors.blue,

                          child: Text(

                            "#${index + 1}",

                            style:
                            const TextStyle(

                              color: Colors
                                  .white,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(
                            width:
                            16),

                        // PLAYER INFO
                        Expanded(

                          child:
                          Column(

                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                            children: [

                              Row(

                                children: [

                                  Expanded(

                                    child:
                                    Text(

                                      player
                                          .name,

                                      style:
                                      const TextStyle(

                                        fontSize:
                                        18,

                                        fontWeight:
                                        FontWeight.bold,
                                      ),
                                    ),
                                  ),

                                  // LEADER BADGE

                                  if (playerIsLeader)

                                    Container(

                                      padding:
                                      const EdgeInsets.symmetric(

                                        horizontal:
                                        10,

                                        vertical:
                                        5,
                                      ),

                                      decoration:
                                      BoxDecoration(

                                        color:
                                        Colors.orange,

                                        borderRadius:
                                        BorderRadius.circular(
                                            20),
                                      ),

                                      child:
                                      const Text(

                                        "LEADER",

                                        style:
                                        TextStyle(

                                          color:
                                          Colors.white,

                                          fontSize:
                                          12,

                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(
                                  height:
                                  8),

                              Text(

                                "${player.totalSteps} steps",
                              ),

                              const SizedBox(
                                  height:
                                  4),

                              Text(

                                "Level ${player.level}",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // =====================
                    // LEADER ACTIONS
                    // =====================

                    if (isLeader &&
                        !playerIsLeader)

                      Column(

                        children: [

                          const SizedBox(
                              height:
                              18),

                          Row(

                            children: [

                              // KICK BUTTON

                              Expanded(

                                child:
                                ElevatedButton.icon(

                                  style:
                                  ElevatedButton.styleFrom(

                                    backgroundColor:
                                    Colors.red,
                                  ),

                                  onPressed:
                                      () async {
                                    await FirebaseService().kickPlayer(
                                      playerId: player.uid,
                                      teamId: teamId,
                                    );

                                    if (context
                                        .mounted) {

                                      ScaffoldMessenger.of(
                                          context)

                                          .showSnackBar(

                                        SnackBar(

                                          backgroundColor:
                                          Colors.red,

                                          content:
                                          Text(

                                            "${player.name} kicked",
                                          ),
                                        ),
                                      );
                                    }
                                  },

                                  icon:
                                  const Icon(
                                    Icons.remove_circle,
                                  ),

                                  label:
                                  const Text(
                                    "Kick",
                                  ),
                                ),
                              ),

                              const SizedBox(
                                  width:
                                  12),

                              // PROMOTE BUTTON (Disabled because coLeader is not in TeamModel)
/*
                              Expanded(

                                child:
                                ElevatedButton.icon(

                                  style:
                                  ElevatedButton.styleFrom(

                                    backgroundColor:
                                    Colors.green,
                                  ),

                                  onPressed:
                                      () async {

                                    await FirebaseFirestore
                                        .instance

                                        .collection(
                                        "teams")

                                        .doc(
                                        leaderId)

                                        .update({

                                      "coLeader":
                                      player.uid,
                                    });

                                    if (context
                                        .mounted) {

                                      ScaffoldMessenger.of(
                                          context)

                                          .showSnackBar(

                                        SnackBar(

                                          backgroundColor:
                                          Colors.green,

                                          content:
                                          Text(

                                            "${player.name} promoted",
                                          ),
                                        ),
                                      );
                                    }
                                  },

                                  icon:
                                  const Icon(
                                    Icons.workspace_premium,
                                  ),

                                  label:
                                  const Text(
                                    "Promote",
                                  ),
                                ),
                              ),
*/
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}