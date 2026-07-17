import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/player_model.dart';
import '../models/mission_model.dart';

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context);
    final user = firebaseService.currentUser;

    if (user == null) return const Scaffold(body: Center(child: Text("NOT AUTHENTICATED")));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0E),
        appBar: AppBar(
          title: const Text("MISSIONS", style: TextStyle(fontFamily: 'Orbitron', letterSpacing: 2)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: "DAILY"),
              Tab(text: "WEEKLY"),
            ],
            indicatorColor: Color(0xFF00F2FF),
            labelStyle: TextStyle(fontFamily: 'Orbitron', fontWeight: FontWeight.bold),
          ),
        ),
        body: StreamBuilder<PlayerModel?>(
          stream: firebaseService.getPlayerStream(user.uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final player = snapshot.data!;

            return TabBarView(
              children: [
                _buildMissionList(context, firebaseService, player, false),
                _buildMissionList(context, firebaseService, player, true),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMissionList(BuildContext context, FirebaseService service, PlayerModel player, bool isWeekly) {
    // These would normally come from Firestore
    final List<MissionModel> mockMissions = [
      MissionModel(
        id: isWeekly ? "w_1" : "d_1",
        title: isWeekly ? "ENDURANCE RUN" : "RECONNAISSANCE",
        description: isWeekly ? "Walk 50km this week." : "Walk 5,000 steps today.",
        type: isWeekly ? MissionType.distance : MissionType.steps,
        target: isWeekly ? 50.0 : 5000.0,
        rewardXp: isWeekly ? 2000 : 200,
        rewardCoins: isWeekly ? 500 : 50,
        isWeekly: isWeekly,
      ),
      MissionModel(
        id: isWeekly ? "w_2" : "d_2",
        title: isWeekly ? "TERRITORY DOMINATION" : "SECURE SECTOR",
        description: isWeekly ? "Capture 2.0 km² of area." : "Capture 0.1 km² of area.",
        type: MissionType.capture,
        target: isWeekly ? 2.0 : 0.1,
        rewardXp: isWeekly ? 5000 : 500,
        rewardCoins: isWeekly ? 1000 : 100,
        isWeekly: isWeekly,
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: mockMissions.length,
      itemBuilder: (context, index) {
        final mission = mockMissions[index];
        final isClaimed = player.claimedQuests.contains(mission.id);
        
        double currentProgress = 0.0;
        if (mission.type == MissionType.steps) {
          currentProgress = player.dailySteps.toDouble();
        } else if (mission.type == MissionType.distance) {
          currentProgress = player.dailyDistance;
        } else if (mission.type == MissionType.capture) {
          currentProgress = (player.totalLand * 0.025); // Rough km² estimate
        }

        double progressPercent = (currentProgress / mission.target).clamp(0.0, 1.0);
        bool canClaim = progressPercent >= 1.0 && !isClaimed;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: canClaim ? const Color(0xFF00F2FF) : Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    mission.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Orbitron'),
                  ),
                  if (isClaimed)
                    const Icon(Icons.check_circle, color: Colors.green)
                  else
                    Text(
                      "${mission.rewardXp} XP | ${mission.rewardCoins}🪙",
                      style: const TextStyle(color: Color(0xFF00F2FF), fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                mission.description,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progressPercent,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(canClaim ? const Color(0xFF00F2FF) : Colors.purpleAccent),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${currentProgress.toStringAsFixed(1)} / ${mission.target.toStringAsFixed(0)}",
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  if (canClaim)
                    ElevatedButton(
                      onPressed: () async {
                        await service.claimQuestReward(player.uid, mission.id, mission.rewardXp);
                        await service.updateCurrency(player.uid, mission.rewardCoins);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00F2FF)),
                      child: const Text("CLAIM", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
