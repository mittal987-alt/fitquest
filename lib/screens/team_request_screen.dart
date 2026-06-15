import 'package:flutter/material.dart';

import '../models/team_request_model.dart';

import '../services/firebase_service.dart';

class TeamRequestsScreen
    extends StatelessWidget {

  final String teamId;

  final String teamName;

  const TeamRequestsScreen({

    super.key,

    required this.teamId,

    required this.teamName,
  });

  @override
  Widget build(BuildContext context) {

    final FirebaseService
    firebaseService =
    FirebaseService();

    return Scaffold(

      backgroundColor:
      Colors.grey.shade100,

      appBar: AppBar(

        title:
        const Text(
            "Join Requests"),

        centerTitle: true,
      ),

      body:
      StreamBuilder<
          List<
              TeamRequestModel>>(

        stream:
        firebaseService
            .getTeamRequests(
            teamId),

        builder:
            (context, snapshot) {

          // LOADING
          if (snapshot
              .connectionState ==
              ConnectionState
                  .waiting) {

            return const Center(

              child:
              CircularProgressIndicator(),
            );
          }

          // EMPTY
          if (!snapshot.hasData ||

              snapshot
                  .data!
                  .isEmpty) {

            return const Center(

              child: Text(

                "No Pending Requests",
              ),
            );
          }

          final requests =
          snapshot.data!;

          return ListView.builder(

            padding:
            const EdgeInsets
                .all(16),

            itemCount:
            requests.length,

            itemBuilder:
                (context, index) {

              final request =
              requests[index];

              return Container(

                margin:
                const EdgeInsets
                    .only(
                  bottom: 16,
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
                      22),

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

                    // =====================
                    // PLAYER INFO
                    // =====================

                    Row(

                      children: [

                        const CircleAvatar(

                          radius:
                          28,

                          child: Icon(
                            Icons
                                .person,
                          ),
                        ),

                        const SizedBox(
                            width:
                            16),

                        Expanded(

                          child:
                          Column(

                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                            children: [

                              Text(

                                request
                                    .playerName,

                                style:
                                const TextStyle(

                                  fontSize:
                                  18,

                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),

                              const SizedBox(
                                  height:
                                  6),

                              Text(

                                "Wants to join $teamName",
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                        height:
                        20),

                    // =====================
                    // ACTION BUTTONS
                    // =====================

                    Row(

                      children: [

                        // REJECT
                        Expanded(

                          child:
                          ElevatedButton(

                            style:
                            ElevatedButton.styleFrom(

                              backgroundColor:
                              Colors.red,

                              padding:
                              const EdgeInsets.symmetric(
                                vertical:
                                14,
                              ),

                              shape:
                              RoundedRectangleBorder(

                                borderRadius:
                                BorderRadius.circular(
                                    16),
                              ),
                            ),

                            onPressed:
                                () async {

                              await firebaseService
                                  .rejectRequest(

                                request
                                    .requestId,
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

                                      "${request.playerName} rejected",
                                    ),
                                  ),
                                );
                              }
                            },

                            child:
                            const Text(
                              "Reject",
                            ),
                          ),
                        ),

                        const SizedBox(
                            width:
                            12),

                        // ACCEPT
                        Expanded(

                          child:
                          ElevatedButton(

                            style:
                            ElevatedButton.styleFrom(

                              backgroundColor:
                              Colors.green,

                              padding:
                              const EdgeInsets.symmetric(
                                vertical:
                                14,
                              ),

                              shape:
                              RoundedRectangleBorder(

                                borderRadius:
                                BorderRadius.circular(
                                    16),
                              ),
                            ),

                            onPressed:
                                () async {

                              await firebaseService
                                  .acceptRequest(

                                requestId:
                                request.requestId,

                                playerId:
                                request.playerId,

                                teamId:
                                request.teamId,

                                teamName:
                                request.teamName,
                              );

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

                                      "${request.playerName} joined $teamName",
                                    ),
                                  ),
                                );
                              }
                            },

                            child:
                            const Text(
                              "Accept",
                            ),
                          ),
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