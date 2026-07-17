import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/power_up_model.dart';
import '../services/firebase_service.dart';
import '../models/player_model.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  static const double _kCardRadius = 24;
  static const Color _bgColor = Color(0xFF0D1117);
  static const Color _cardColor = Color(0xFF161B22);

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final uid = firebaseService.auth.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(
        backgroundColor: _bgColor,
        body: Center(
          child: Text(
            "NOT LOGGED IN",
            style: TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "POWER-UP SHOP",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<PlayerModel?>(
        stream: firebaseService.getPlayerStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF8E2DE2)));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(
              child: Text(
                "SHOP CURRENTLY UNAVAILABLE",
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            );
          }

          final player = snapshot.data!;

          return CustomScrollView(
            slivers: [
              // CURRENCY BALANCE CARD
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(_kCardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8E2DE2).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "CORE CREDITS",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "${player.currency}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stars_rounded, color: Colors.white, size: 32),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    "TACTICAL ENHANCEMENTS",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white38,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = shopItems[index];
                      final bool canAfford = player.currency >= item.cost;
                      final Color itemThemeColor = item.color;
                      final bool isActive = player.activePowerUps.containsKey(item.id) &&
                          player.activePowerUps[item.id]!.isAfter(DateTime.now());

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(_kCardRadius),
                          border: Border.all(
                            color: isActive ? itemThemeColor.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: itemThemeColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: itemThemeColor.withValues(alpha: 0.2)),
                                ),
                                child: Icon(item.icon, color: itemThemeColor, size: 32),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item.name.toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            color: Colors.white,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        if (isActive) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.greenAccent.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              "ACTIVE",
                                              style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.description,
                                      style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "${item.cost} CREDITS",
                                          style: TextStyle(
                                            color: itemThemeColor,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: canAfford ? itemThemeColor.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                                            foregroundColor: canAfford ? itemThemeColor : Colors.white24,
                                            elevation: 0,
                                            side: BorderSide(
                                              color: canAfford ? itemThemeColor.withValues(alpha: 0.3) : Colors.white10,
                                              width: 1.5,
                                            ),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                                                  content: Text("ACTIVATED: ${item.name.toUpperCase()}"),
                                                  backgroundColor: itemThemeColor,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            } catch (e) {
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text("PURCHASE ERROR: $e"),
                                                  backgroundColor: Colors.redAccent,
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                          } : null,
                                          child: Text(
                                            isActive ? "EXTEND" : "BUY",
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: shopItems.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
