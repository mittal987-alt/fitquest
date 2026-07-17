import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/gameplay_rules.dart';

/// Represents the localized status of a player inside the active co-op raid.
class RaidParticipant {
  final String playerUid;
  final String displayName;
  int stepsContributed;
  double damageContributed;
  double ghostDamageContributed;
  bool hasPatchedFirewall;

  RaidParticipant({
    required this.playerUid,
    required this.displayName,
    this.stepsContributed = 0,
    this.damageContributed = 0.0,
    this.ghostDamageContributed = 0.0,
    this.hasPatchedFirewall = false,
  });

  /// Factory method to clone with state updates
  RaidParticipant copyWith({
    int? stepsContributed,
    double? damageContributed,
    double? ghostDamageContributed,
    bool? hasPatchedFirewall,
  }) {
    return RaidParticipant(
      playerUid: playerUid,
      displayName: displayName,
      stepsContributed: stepsContributed ?? this.stepsContributed,
      damageContributed: damageContributed ?? this.damageContributed,
      ghostDamageContributed: ghostDamageContributed ?? this.ghostDamageContributed,
      hasPatchedFirewall: hasPatchedFirewall ?? this.hasPatchedFirewall,
    );
  }
}

/// Dynamic state manager for handling sequential and cooperative step raids.
/// Connects the UI layers reactively to Firestore real-time streams.
class RaidController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Throttles a stream to prevent rapid UI rebuilds and jitter.
  Stream<T> _throttleStream<T>(Stream<T> source, {Duration duration = const Duration(seconds: 15)}) {
    StreamController<T> controller = StreamController<T>.broadcast();
    Timer? timer;
    T? latestValue;
    bool hasValue = false;

    source.listen((value) {
      latestValue = value;
      hasValue = true;

      if (timer == null) {
        controller.add(value);
        timer = Timer(duration, () {
          timer = null;
          if (hasValue && latestValue != null) {
            controller.add(latestValue!);
          }
        });
      }
    }, onDone: () => controller.close(), onError: (e) => controller.addError(e));

    return controller.stream;
  }

  // --- STATE PROPERTIES ---
  String? _activeRaidId;
  String? _teamId;
  String _bossName = "VOID TITAN";
  String _bossElement = "Void";
  String _bossWeakness = "Light";
  double _bossMaxHp = 150000.0;
  double _bossCurrentHp = 150000.0;
  bool _isSystemHackActive = true;
  DateTime? _raidExpiryTime;

  final Map<String, RaidParticipant> _participants = {};
  final List<Map<String, dynamic>> _tacticalPings = [];
  Timer? _regenTimer;

  StreamSubscription? _teamSubscription;
  StreamSubscription? _membersSubscription;
  StreamSubscription? _eventSubscription;
  StreamSubscription? _pingSubscription;

  // --- GETTERS ---
  String? get activeRaidId => _activeRaidId;
  String? get teamId => _teamId;
  String get bossName => _bossName;
  double get bossMaxHp => _bossMaxHp;
  double get bossCurrentHp => _bossCurrentHp;
  bool get isSystemHackActive => _isSystemHackActive;
  DateTime? get raidExpiryTime => _raidExpiryTime;
  List<RaidParticipant> get participants => _participants.values.toList();
  List<Map<String, dynamic>> get tacticalPings => List.unmodifiable(_tacticalPings);

  double get bossHpPercentage => (_bossCurrentHp / _bossMaxHp).clamp(0.0, 1.0);
  bool get isRaidActive => (_activeRaidId != null || _teamId != null) && _bossCurrentHp > 0 && !isExpired;

  bool get isExpired {
    if (_raidExpiryTime == null) return false;
    return DateTime.now().isAfter(_raidExpiryTime!);
  }

  /// Initializes the controller for a specific team, binding Firestore listeners.
  void initTeamRaid(String teamId) {
    if (_teamId == teamId) return;
    _teamId = teamId;
    _activeRaidId = "raid_$teamId"; // Simplified ID mapping

    _teamSubscription?.cancel();
    _membersSubscription?.cancel();
    _eventSubscription?.cancel();
    _pingSubscription?.cancel();

    // 1. Listen to Team Document for Boss HP and Expiry
    _teamSubscription = _throttleStream(_firestore.collection("teams").doc(teamId).snapshots())
        .listen((snap) {
      if (snap.exists) {
        final data = snap.data()!;
        final bossId = data["raidBossId"] ?? "void_titan";
        
        // Find boss config
        final bossConfig = GameplayRules.bossPool.firstWhere(
          (b) => b["id"] == bossId,
          orElse: () => GameplayRules.bossPool[0],
        );

        _bossName = bossConfig["name"];
        _bossMaxHp = (bossConfig["maxHp"] as num).toDouble();
        _bossElement = bossConfig["element"];
        _bossWeakness = bossConfig["weakness"];
        _bossCurrentHp = (data["raidBossHp"] ?? _bossMaxHp).toDouble();

        final Timestamp? expiry = data["raidExpiry"] as Timestamp?;
        _raidExpiryTime = expiry?.toDate();

        debugPrint("RAID SYNC [TEAM]: Boss HP @ $_bossCurrentHp");
        notifyListeners();
      }
    });

    // 2. Listen to Team Members (Players)
    // NOTE: this is the single source of truth for RaidParticipant.stepsContributed
    // (total daily steps, not raid-specific steps) — confirmed intentional.
    // registerPlayerSteps() below no longer increments it separately.
    _membersSubscription = _throttleStream(_firestore
        .collection("players")
        .where("teamId", isEqualTo: teamId)
        .snapshots())
        .listen((snap) {
      for (var doc in snap.docs) {
        final data = doc.data();
        final uid = doc.id;
        final name = data["name"] ?? "Unknown";

        if (_participants.containsKey(uid)) {
          _participants[uid] = _participants[uid]!.copyWith(
            stepsContributed: (data["dailySteps"] as num?)?.toInt() ?? 0,
          );
        } else {
          _participants[uid] = RaidParticipant(
            playerUid: uid,
            displayName: name,
            stepsContributed: (data["dailySteps"] as num?)?.toInt() ?? 0,
          );
        }
      }
      _evaluateGlobalHackStatus();
      notifyListeners();
    });

    // 3. Listen to Events sub-collection for real-time broadcasts
    _eventSubscription = _firestore
        .collection("teams")
        .doc(teamId)
        .collection("events")
        .where("timestamp", isGreaterThan: Timestamp.now())
        .orderBy("timestamp", descending: true)
        .limit(10)
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _handleRaidEvent(change.doc.data() as Map<String, dynamic>);
        }
      }
    });

    // 3. Listen to Tactical Pings
    _pingSubscription = _throttleStream(_firestore
        .collection("teams")
        .doc(teamId)
        .collection("pings")
        .orderBy("timestamp", descending: true)
        .limit(5)
        .snapshots())
        .listen((snap) {
      _tacticalPings.clear();
      for (var doc in snap.docs) {
        _tacticalPings.add(doc.data());
      }
      notifyListeners();
    });

    notifyListeners();
  }

  void _handleRaidEvent(Map<String, dynamic> data) {
    final type = data["type"];
    if (type == "BOSS_HP_SYNC") {
      final double syncedHp = (data["hp"] ?? _bossCurrentHp).toDouble();
      // Only update if discrepancy is significant to avoid jitter
      if ((syncedHp - _bossCurrentHp).abs() > 1.0) {
        _bossCurrentHp = syncedHp;
        notifyListeners();
      }
    } else if (type == "RAID_DAMAGE") {
      final String playerName = data["playerName"] ?? "Unknown";
      final double damage = (data["damage"] ?? 0.0).toDouble();
      debugPrint("RAID ALERT: $playerName dealt $damage damage!");
      // Local HP prediction could happen here before document sync
    } else if (type == "RAID_COMPLETED") {
      _bossCurrentHp = 0;
      _handleRaidSuccess();
      notifyListeners();
    }
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

    // 3. Listen to Tactical Pings
    _pingSubscription = _throttleStream(_firestore
        .collection("teams")
        .doc(teamId)
        .collection("pings")
        .orderBy("timestamp", descending: true)
        .limit(5)
        .snapshots())
        .listen((snap) {
      _tacticalPings.clear();
      for (var doc in snap.docs) {
        _tacticalPings.add(doc.data());
      }
      notifyListeners();
    });

    notifyListeners();
  }

  /// Sends a tactical ping to the team raid channel
  Future<void> sendTacticalPing(String playerUid, String playerName, String message) async {
    if (_teamId == null) return;

    await _firestore.collection("teams").doc(_teamId).collection("pings").add({
      'playerUid': playerUid,
      'playerName': playerName,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Terminates the current active raid tracker and clears loops
  void shutdownController() {
    _regenTimer?.cancel();
    _activeRaidId = null;
    notifyListeners();
  }


  /// Processes steps synced by a player, translates them to damage vector,
  /// and validates firewall patches.
  void registerPlayerSteps(String playerUid, int stepsToSync, {double damageMultiplier = 1.0, double? damageOverride, bool isAheadOfGhost = false}) {
    if (!isRaidActive) return;

    final participant = _participants[playerUid];
    if (participant == null) return;

    // 1 step = 1 HP damage dealt to Colossus defenses (modified by tier multiplier)
    // If damageOverride is provided, use it directly (already calculated with multipliers)
    final double rawDamage = damageOverride ?? (stepsToSync * GameplayRules.damagePerStep * damageMultiplier);
    _bossCurrentHp = (_bossCurrentHp - rawDamage).clamp(0.0, _bossMaxHp);

    // FIX: this used to also do `participant.stepsContributed += stepsToSync;`
    // here, which fought with the _membersSubscription listener above that
    // periodically overwrites stepsContributed with the player's total
    // dailySteps — whichever fired last would silently clobber the other.
    // Confirmed dailySteps (from the listener) should be the single source
    // of truth, so the increment here is removed; damage/ghost-damage
    // tracking is unaffected since those aren't touched by the listener.
    participant.damageContributed += rawDamage;

    if (isAheadOfGhost) {
      participant.ghostDamageContributed += rawDamage;
    }

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
    _teamSubscription?.cancel();
    _membersSubscription?.cancel();
    _eventSubscription?.cancel();
    _pingSubscription?.cancel();
    super.dispose();
  }
}