class GameplayRules {
  // --- LOCATION & GEO-FENCING CONSTANTS ---
  /// Maximum radius in meters for spawning local grid anomalies: $r \le 500\text{ m}$
  static const double anomalySpawnRadiusMeters = 500.0;

  /// Minimum distance in meters to trigger an extraction ping event
  static const double extractionTriggerRadiusMeters = 30.0;

  // --- STEP CONVERSION COEFFICIENTS ---
  /// Average calories burned per step: $\text{kcal} = \text{steps} \times 0.04$
  static const double caloriesPerStep = 0.04;

  /// Average distance in kilometers traversed per step: $\text{km} = \text{steps} \times 0.00075$
  static const double distanceKmPerStep = 0.00075;

  // --- GHOST STRIDER CONFIGURATION ---
  /// Multiplier applied to trust scores when defeating your personal historical ghost
  static const int ghostStriderTrustReward = 50;

  /// Default step telemetry sample window in hours
  static const int telemetrySampleWindowHours = 24;

  // --- COLOSSUS RAID SYSTEM ---
  /// Default collective target health index: $100,000\text{ HP}$
  static const double colossusMaxHp = 100000.0;

  /// Damage dealt per registered physical step: $1\text{ step} = 1\text{ HP damage}$
  static const double damagePerStep = 1.0;

  /// Hourly automatic boss health recovery multiplier: $\text{Heal} = \text{Current HP} \times 0.005$
  static const double colossusHourlyRegenFactor = 0.005;

  /// Active system hack penalty: $-20\%$ multiplier applied to XP rewards
  static const double systemHackXpPenalty = 0.20;

  /// Step count required for an individual to patch active firewalls and lift penalties
  static const int firewallPatchStepRequirement = 3000;

  // --- RECOVERY & AP POOLS ---
  /// Maximum stamina Action Points (AP) base limit
  static const int baseMaxStamina = 100;

  /// Stamina recovery multiplier per 1,000 steps completed
  static const int staminaRefillPerThousandSteps = 10;
}