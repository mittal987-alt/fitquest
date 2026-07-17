import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/player_model.dart';
import 'firebase_service.dart';

class TreasureService {
  final FirebaseService _firebaseService = FirebaseService();

  List<LatLng> spawnChests(LatLng center, int count) {
    final Random random = Random();
    List<LatLng> chests = [];
    
    for (int i = 0; i < count; i++) {
      // Spawn within ~500m radius
      double latOffset = (random.nextDouble() - 0.5) * 0.01;
      double lngOffset = (random.nextDouble() - 0.5) * 0.01;
      chests.add(LatLng(center.latitude + latOffset, center.longitude + lngOffset));
    }
    return chests;
  }

  Future<void> claimChest(String uid, String chestType) async {
    // Reward logic based on chest type
    int xpReward = 50;
    String material = "Scrap Metal";
    
    if (chestType == "rare") {
      xpReward = 200;
      material = "Titanium Plate";
    }

    await _firebaseService.incrementXP(uid: uid, xpToAdd: xpReward);
    await _firebaseService.addInventoryItem(uid, material, 1);
  }
}
