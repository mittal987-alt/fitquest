import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_model.dart';
import '../config/crafting_recipes.dart';
import '../services/firebase_service.dart';

class CraftingScreen extends StatelessWidget {
  const CraftingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "MATERIEL SYNTHESIZER",
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
            return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("OFFLINE"));
          }

          final player = snapshot.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // INVENTORY SUMMARY
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "RAW MATERIALS CACHE",
                      style: TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInventoryItem(
                          "Silicon",
                          player.inventory[CraftingRecipes.materialSilicon] ?? 0,
                          Icons.grid_3x3_rounded,
                          Colors.amber,
                        ),
                        _buildInventoryItem(
                          "Energy Core",
                          player.inventory[CraftingRecipes.materialEnergyCore] ?? 0,
                          Icons.blur_on_rounded,
                          Colors.deepPurpleAccent,
                        ),
                        _buildInventoryItem(
                          "Nanites",
                          player.inventory[CraftingRecipes.materialNanites] ?? 0,
                          Icons.bubble_chart_rounded,
                          Colors.cyan,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  "SYNTHESIS BLUEPRINTS",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black45, letterSpacing: 1),
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: CraftingRecipes.recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = CraftingRecipes.recipes[index];
                    final canCraft = CraftingRecipes.canPlayerCraft(
                      recipe: recipe,
                      playerInventory: player.inventory,
                      playerCurrentStamina: player.currentStamina,
                    );

                    return _buildRecipeCard(context, recipe, player, canCraft, firebaseService);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInventoryItem(String label, int count, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          "$count",
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        Text(
          label.toUpperCase(),
          style: const TextStyle(color: Colors.black38, fontSize: 8, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRecipeCard(BuildContext context, CraftingRecipe recipe, PlayerModel player, bool canCraft, FirebaseService firebaseService) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.resultName.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Required: ${recipe.apCraftingCost} Stamina",
                        style: TextStyle(color: player.currentStamina >= recipe.apCraftingCost ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: canCraft ? () async {
                    bool success = await firebaseService.craftGear(
                      player.uid,
                      recipe.resultItemId,
                      recipe.requiredMaterials,
                    );
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("SYNTHESIS SUCCESSFUL: ${recipe.resultName}")),
                      );
                    }
                  } : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.black.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text("SYNTHESIZE", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: recipe.requiredMaterials.entries.map((entry) {
                final materialId = entry.key;
                final requiredCount = entry.value;
                final currentCount = player.inventory[materialId] ?? 0;
                final bool hasEnough = currentCount >= requiredCount;

                String name = "Material";
                if (materialId == CraftingRecipes.materialSilicon) name = "Silicon";
                if (materialId == CraftingRecipes.materialEnergyCore) name = "Core";
                if (materialId == CraftingRecipes.materialNanites) name = "Nanites";

                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasEnough ? Colors.green.withOpacity(0.05) : Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: hasEnough ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "$currentCount/$requiredCount ",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: hasEnough ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
