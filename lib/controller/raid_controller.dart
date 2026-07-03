import 'dart:async';
import 'package:flutter/foundation.dart';
import '../config/gameplay_rules.dart';

/// Represents the localized status of a player inside the active co-op raid.
class RaidParticipant {
  final String playerUid;
  final String displayName;
  int stepsContributed;
  bool hasPatchedFirewall;

  RaidParticipant({
    required this.playerUid,
    required this.displayName,
    this.stepsContributed = 0,
    this.hasPatchedFirewall = false,
  });

  /// Factory method to clone with state updates
  RaidParticipant copyWith({
    int? stepsContributed,
    bool? hasPatchedFirewall,
  }) {
    return RaidParticipant(
      playerUid: playerUid,
      displayName: displayName,
      stepsContributed: stepsContributed ?? this.stepsContributed,
      hasPatchedFirewall: hasPatchedFirewall ?? this.hasPatchedFirewall,
    );
  }
}

/// Dynamic state manager for handling sequential and cooperative step raids.
/// Connects the UI layers reactively to simulated database feeds.
class RaidController extends ChangeNotifier {
  // --- STATE PROPERTIES ---
  String? _activeRaidId;
  String _bossName = "GLITCH_COLOSSUS_V4";
  double _bossMaxHp = GameplayRules.colossusMaxHp;
  double _bossCurrentHp = GameplayRules.colossusMaxHp;
  bool _isSystemHackActive = true;
  DateTime? _raidExpiryTime;

  final Map<String, RaidParticipant> _participants = {};
  Timer? _regenTimer;

  // --- GETTERS ---
  String? get activeRaidId => _activeRaidId;
  String get bossName => _bossName;
  double get bossMaxHp => _bossMaxHp;
  double get bossCurrentHp => _bossCurrentHp;
  bool get isSystemHackActive => _isSystemHackActive;
  DateTime? get raidExpiryTime => _raidExpiryTime;
  List<RaidParticipant> get participants => _participants.values.toList();

  double get bossHpPercentage => (_bossCurrentHp / _bossMaxHp).clamp(0.0, 1.0);
  bool get isRaidActive => _activeRaidId != null && _bossCurrentHp > 0 && !isExpired;

  bool get isExpired {
    if (_raidExpiryTime == null) return false;
    return DateTime.now().isAfter(_raidExpiryTime!);
  }


  /// Initiates a new Colossus Raid instance across the cooperative operator cell.
  void startNewRaid({
    required String raidId,
    required String bossName,
    required List<RaidParticipant> teamMembers,
    Duration duration = const Duration(hours: 24),
  }) {
    _activeRaidId = raidId;
    _bossName = bossName;
    _bossMaxHp = GameplayRules.colossusMaxHp;
    _bossCurrentHp = GameplayRules.colossusMaxHp;
    _isSystemHackActive = true; // Boss begins with an active firewall debuff
    _raidExpiryTime = DateTime.now().add(duration);

    _participants.clear();
    for (var member in teamMembers) {
      _participants[member.playerUid] = member;
    }

    // Cancel existing timer loop before initializing a new one
    _regenTimer?.cancel();

    // Set up recurring hourly health regeneration simulation (scaled to 1 minute for local preview testing)
    _regenTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _applyBossRegeneration();
    });

    notifyListeners();
  }

  /// Terminates the current active raid tracker and clears loops
  void shutdownController() {
    _regenTimer?.cancel();
    _activeRaidId = null;
    notifyListeners();
  }


  /// Processes steps synced by a player, translates them to damage vector,
  /// and validates firewall patches.
  void registerPlayerSteps(String playerUid, int stepsToSync) {
    if (!isRaidActive) return;

    final participant = _participants[playerUid];
    if (participant == null) return;

    // 1 step = 1 HP damage dealt to Colossus defenses
    final double rawDamage = stepsToSync * GameplayRules.damagePerStep;
    _bossCurrentHp = (_bossCurrentHp - rawDamage).clamp(0.0, _bossMaxHp);

    // Track total steps contributed during this operational shift
    participant.stepsContributed += stepsToSync;

    // Check if the player contribution meets criteria to patch active firewall penalty
    if (!participant.hasPatchedFirewall &&
        participant.stepsContributed >= GameplayRules.firewallPatchStepRequirement) {
      participant.hasPatchedFirewall = true;
      _evaluateGlobalHackStatus();
    }

    if (_bossCurrentHp <= 0) {
      _handleRaidSuccess();
    }

    notifyListeners();
  }


  /// Applies hourly regeneration logic based on custom mathematical curves
  void _applyBossRegeneration() {
    if (!isRaidActive) return;

    // Heal = Current HP * 0.005 (GameplayRules.colossusHourlyRegenFactor)
    final double healingAmount = _bossCurrentHp * GameplayRules.colossusHourlyRegenFactor;
    _bossCurrentHp = (_bossCurrentHp + healingAmount).clamp(0.0, _bossMaxHp);

    notifyListeners();
  }

  /// Evaluates whether any cell member has patched the system firewall yet.
  /// The global system hack (penalty) is lifted as soon as at least one participant patches it.
  void _evaluateGlobalHackStatus() {
    bool anyPatchApplied = _participants.values.any((p) => p.hasPatchedFirewall);
    if (anyPatchApplied && _isSystemHackActive) {
      _isSystemHackActive = false;
    }
  }

  /// Actions fired when boss health reaches zero
  void _handleRaidSuccess() {
    _regenTimer?.cancel();
    // Dispatch system events or rewards here
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    super.dispose();
  }
}