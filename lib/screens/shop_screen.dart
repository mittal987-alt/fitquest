import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/power_up_model.dart';
import '../services/firebase_service.dart';
import '../models/player_model.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "XP ARMORY SHOP",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<PlayerModel?>(
        stream: firebaseService.getPlayerStream(firebaseService.auth.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text(
                "ARMORY CACHE OFFLINE",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            );
          }

          final player = snapshot.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // XP BALANCE CARD
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.05),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "AVAILABLE RESERVES",
                          style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${player.xp} XP",
                          style: const TextStyle(color: Colors.black87, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                    const Icon(Icons.stars_rounded, color: Colors.blueAccent, size: 40),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  "AVAILABLE POWER-UPS",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black45, letterSpacing: 1),
                ),
              ),

              const SizedBox(height: 4),

              // SHOP MATRIX ITEMS LIST
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: shopItems.length,
                  itemBuilder: (context, index) {
                    final item = shopItems[index];
                    final bool canAfford = player.xp >= item.cost;
                    final Color itemThemeColor = item.color;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: itemThemeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: itemThemeColor.withValues(alpha: 0.2)),
                          ),
                          child: Icon(item.icon, color: itemThemeColor, size: 26),
                        ),
                        title: Text(
                          item.name.toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black87, letterSpacing: 0.5),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              item.description,
                              style: const TextStyle(color: Colors.black54, fontSize: 12, height: 1.3),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "${item.cost} XP",
                              style: TextStyle(color: itemThemeColor, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: canAfford ? itemThemeColor.withValues(alpha: 0.15) : Colors.transparent,
                            foregroundColor: canAfford ? itemThemeColor : Colors.black12,
                            elevation: 0,
                            side: BorderSide(
                              color: canAfford ? itemThemeColor.withValues(alpha: 0.4) : Colors.black12,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onPressed: canAfford ? () async {
                            try {
                              await firebaseService.purchasePowerUp(
                                uid: player.uid,
                                powerUpId: item.id,
                                cost: item.cost,
                                duration: item.duration,
                              );

                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("DEPLOYED: ${item.name.toUpperCase()} ACCESSED"),
                                  backgroundColor: itemThemeColor.withValues(alpha: 0.8),
                                ),
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("ACQUISITION FAULT: $e"),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          } : null,
                          child: const Text(
                            "BUY",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
