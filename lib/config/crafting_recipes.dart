class CraftingRecipe {
  final String recipeId;
  final String resultItemId;
  final String resultName;
  final Map<String, int> requiredMaterials; // MaterialID -> Quantity
  final int apCraftingCost;
  final Duration activeDuration;

  const CraftingRecipe({
    required this.recipeId,
    required this.resultItemId,
    required this.resultName,
    required this.requiredMaterials,
    required this.apCraftingCost,
    required this.activeDuration,
  });
}

class CraftingRecipes {
  // Standard Item Identifiers matching shop configurations
  static const String materialSilicon = "raw_silicon";
  static const String materialEnergyCore = "dark_energy_core";
  static const String materialNanites = "nanite_paste";

  static const List<CraftingRecipe> recipes = [
    CraftingRecipe(
      recipeId: "recipe_xp_boost",
      resultItemId: "boost",
      resultName: "XP 2X BOOST",
      requiredMaterials: {
        materialSilicon: 3,
        materialEnergyCore: 1,
      },
      apCraftingCost: 15,
      activeDuration: Duration(minutes: 30),
    ),
    CraftingRecipe(
      recipeId: "recipe_radar_sweep",
      resultItemId: "radar_sweep",
      resultName: "RADAR OVERDRIVE",
      requiredMaterials: {
        materialSilicon: 2,
        materialNanites: 2,
      },
      apCraftingCost: 10,
      activeDuration: Duration(minutes: 15),
    ),
    CraftingRecipe(
      recipeId: "recipe_firewall_patch",
      resultItemId: "firewall_patch",
      resultName: "SECURE PATCH MODULE",
      requiredMaterials: {
        materialEnergyCore: 2,
        materialNanites: 1,
      },
      apCraftingCost: 20,
      activeDuration: Duration(hours: 1),
    ),
    CraftingRecipe(
      recipeId: "recipe_titan_greaves",
      resultItemId: "titan_greaves",
      resultName: "TITAN GREAVES",
      requiredMaterials: {
        materialSilicon: 15,
        materialEnergyCore: 5,
        materialNanites: 5,
      },
      apCraftingCost: 50,
      activeDuration: Duration.zero,
    ),
    CraftingRecipe(
      recipeId: "recipe_overseer_eye",
      resultItemId: "overseer_eye",
      resultName: "OVERSEER EYE",
      requiredMaterials: {
        materialSilicon: 10,
        materialEnergyCore: 10,
        materialNanites: 5,
      },
      apCraftingCost: 60,
      activeDuration: Duration.zero,
    ),
    CraftingRecipe(
      recipeId: "recipe_quantum_comm",
      resultItemId: "quantum_comm",
      resultName: "QUANTUM COMM",
      requiredMaterials: {
        materialSilicon: 5,
        materialEnergyCore: 8,
        materialNanites: 12,
      },
      apCraftingCost: 70,
      activeDuration: Duration.zero,
    ),
  ];

  /// Checks if a player has the required inventory components to craft a recipe
  static bool canPlayerCraft({
    required CraftingRecipe recipe,
    required Map<String, int> playerInventory,
    required int playerCurrentStamina,
  }) {
    if (playerCurrentStamina < recipe.apCraftingCost) return false;

    for (var entry in recipe.requiredMaterials.entries) {
      final available = playerInventory[entry.key] ?? 0;
      if (available < entry.value) {
        return false;
      }
    }
    return true;
  }
}