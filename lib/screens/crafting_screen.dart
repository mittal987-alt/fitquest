import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/player_model.dart';
import '../config/crafting_recipes.dart';
import '../services/firebase_service.dart';

class CraftingScreen extends StatelessWidget {
  const CraftingScreen({super.key});

  static const double _kCardRadius = 24;
  static const double _kChipRadius = 12;

  BoxDecoration _cardDecoration(ThemeData theme, {Color? borderColor, double borderWidth = 1}) {
    return BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(_kCardRadius),
      border: Border.all(color: borderColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.1), width: borderWidth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "CRAFTING STATION",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: StreamBuilder<PlayerModel?>(
        stream: firebaseService.getPlayerStream(firebaseService.auth.currentUser?.uid ?? ""),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text("OFFLINE", style: TextStyle(color: theme.colorScheme.onSurface)));
          }

          final player = snapshot.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // INVENTORY SUMMARY
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: _cardDecoration(theme),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "MATERIALS INVENTORY",
                      style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
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
                          theme,
                        ),
                        _buildInventoryItem(
                          "Energy Core",
                          player.inventory[CraftingRecipes.materialEnergyCore] ?? 0,
                          Icons.blur_on_rounded,
                          theme.colorScheme.primary,
                          theme,
                        ),
                        _buildInventoryItem(
                          "Nanites",
                          player.inventory[CraftingRecipes.materialNanites] ?? 0,
                          Icons.bubble_chart_rounded,
                          Colors.cyanAccent,
                          theme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  "CRAFTING BLUEPRINTS",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), letterSpacing: 1),
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

                    return _buildRecipeCard(context, recipe, player, canCraft, firebaseService, theme);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInventoryItem(String label, int count, IconData icon, Color color, ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          "$count",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: theme.colorScheme.onSurface),
        ),
        Text(
          label.toUpperCase(),
          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 8, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRecipeCard(BuildContext context, CraftingRecipe recipe, PlayerModel player, bool canCraft, FirebaseService firebaseService, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(theme),
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
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Required: ${recipe.apCraftingCost} Stamina",
                        style: TextStyle(color: player.currentStamina >= recipe.apCraftingCost ? Colors.greenAccent : Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: canCraft ? LinearGradient(
                      colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ) : null,
                    borderRadius: BorderRadius.circular(_kChipRadius),
                  ),
                  child: ElevatedButton(
                    onPressed: canCraft ? () async {
                      bool success = await firebaseService.craftGear(
                        player.uid,
                        recipe.resultItemId,
                        recipe.requiredMaterials,
                      );
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("CRAFTING SUCCESSFUL: ${recipe.resultName}"),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          ),
                        );
                      }
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_kChipRadius)),
                      elevation: 0,
                    ),
                    child: const Text("CRAFT", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
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
                    color: hasEnough ? Colors.greenAccent.withValues(alpha: 0.05) : Colors.redAccent.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(_kChipRadius - 2),
                    border: Border.all(color: hasEnough ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.redAccent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        "$currentCount/$requiredCount ",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: hasEnough ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                      Text(
                        name,
                        style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.54), fontWeight: FontWeight.bold),
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
