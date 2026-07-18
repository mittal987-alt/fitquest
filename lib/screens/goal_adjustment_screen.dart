import 'package:flutter/material.dart';
import '../models/player_model.dart';
import '../services/firebase_service.dart';
import '../models/activity_model.dart';

class GoalAdjustmentScreen extends StatefulWidget {
  final PlayerModel player;

  const GoalAdjustmentScreen({super.key, required this.player});

  @override
  State<GoalAdjustmentScreen> createState() => _GoalAdjustmentScreenState();
}

class _GoalAdjustmentScreenState extends State<GoalAdjustmentScreen> {
  late double _height;
  late double _weight;
  late String _goal;
  late int _stepTarget;
  late int _exerciseTarget;
  late Map<String, int> _hourlySteps;
  late Map<String, dynamic> _dailyHistory;
  bool _isSaving = false;

  static const double _kCardRadius = 24;
  static const double _kChipRadius = 12;
  static const double _kSectionGap = 20;

  BoxDecoration _cardDecoration({Color? borderColor, double borderWidth = 1}) {
    return BoxDecoration(
      color: const Color(0xFF161B22),
      borderRadius: BorderRadius.circular(_kCardRadius),
      border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.05), width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white38, letterSpacing: 1),
    );
  }

  @override
  void initState() {
    super.initState();
    _height = widget.player.heightCm ?? 170.0;
    _weight = widget.player.weightKg ?? 65.0;
    _goal = widget.player.fitnessGoal ?? "maintenance";
    _stepTarget = widget.player.dailyStepTarget;
    _exerciseTarget = widget.player.dailyExerciseTargetMinutes;
    _hourlySteps = Map<String, int>.from(widget.player.hourlySteps);
    _dailyHistory = Map<String, dynamic>.from(widget.player.dailyHistory);
  }

  ActivityModel _computeRecommendation() {
    double meters = _height / 100;
    double bmi = _weight / (meters * meters);
    return ActivityModel.fromBmiAndGoal(
      bmi, 
      _goal, 
      trustScore: widget.player.trustScore, 
      level: widget.player.level
    );
  }

  void _applyRecommendation() {
    final rec = _computeRecommendation();
    setState(() {
      // Step targets usually scale with BMI/Goal in our heuristic
      // We can derive a suggested step target from the tier
      if (rec.tier == "ELITE") {
        _stepTarget = 12000;
      } else if (rec.tier == "RESTORATIVE") {
        _stepTarget = 6000;
      } else {
        _stepTarget = 10000;
      }
      _exerciseTarget = rec.durationMinutes;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("ML RECOMMENDATIONS APPLIED"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rec = _computeRecommendation();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        title: const Text(
          "ADAPTIVE GOALS",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5, fontSize: 18),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(rec),
            const SizedBox(height: _kSectionGap),
            _sectionHeader("BIOMETRIC INPUTS"),
            const SizedBox(height: 12),
            _buildInputSection(),
            const SizedBox(height: _kSectionGap),
            _sectionHeader("TARGET ADJUSTMENT"),
            const SizedBox(height: 12),
            _buildTargetSliders(),
            const SizedBox(height: _kSectionGap),
            _sectionHeader("HISTORICAL TELEMETRY (DEBUG)"),
            const SizedBox(height: 12),
            _buildHistoricalTelemetrySection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoricalTelemetrySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "MANUAL TELEMETRY OVERRIDE",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white54, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          const Text(
            "Directly modify hourly baselines or daily logs for testing Ghost Strider performance.",
            style: TextStyle(color: Colors.white24, fontSize: 10),
          ),
          const SizedBox(height: 20),
          _telemetryActionTile(
            "HOURLY STEP DISTRIBUTION",
            Icons.access_time_filled_rounded,
            () => _showHourlyEditor(),
          ),
          const Divider(height: 1, color: Colors.white10),
          _telemetryActionTile(
            "DAILY ARCHIVE LOGS",
            Icons.calendar_month_rounded,
            () => _showDailyHistoryEditor(),
          ),
        ],
      ),
    );
  }

  Widget _telemetryActionTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.cyanAccent, size: 20),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24),
      onTap: onTap,
    );
  }

  void _showHourlyEditor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "EDIT HOURLY DISTRIBUTION",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: 24,
                    itemBuilder: (context, index) {
                      final hour = index.toString().padLeft(2, '0');
                      final steps = _hourlySteps[hour] ?? 0;
                      return ListTile(
                        title: Text("HOUR $hour:00", style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        trailing: SizedBox(
                          width: 100,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              hintText: "Steps",
                              hintStyle: TextStyle(color: Colors.white10),
                              isDense: true,
                            ),
                            onChanged: (val) {
                              final intValue = int.tryParse(val) ?? 0;
                              setState(() => _hourlySteps[hour] = intValue);
                            },
                            controller: TextEditingController(text: steps.toString())..selection = TextSelection.fromPosition(TextPosition(offset: steps.toString().length)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CLOSE & PREVIEW", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDailyHistoryEditor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final sortedDates = _dailyHistory.keys.toList()..sort((a, b) => b.compareTo(a));
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    "DAILY HISTORY ARCHIVE",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: sortedDates.length,
                    itemBuilder: (context, index) {
                      final date = sortedDates[index];
                      final data = _dailyHistory[date] as Map<String, dynamic>;
                      final steps = data['steps'] ?? 0;
                      return ListTile(
                        title: Text(date, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text("${data['calories'] ?? 0} KCAL | ${data['distance'] ?? 0.0} KM", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                        trailing: SizedBox(
                          width: 100,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(isDense: true),
                            onChanged: (val) {
                              final intValue = int.tryParse(val) ?? 0;
                              setState(() {
                                final current = Map<String, dynamic>.from(_dailyHistory[date]);
                                current['steps'] = intValue;
                                _dailyHistory[date] = current;
                              });
                            },
                            controller: TextEditingController(text: steps.toString())..selection = TextSelection.fromPosition(TextPosition(offset: steps.toString().length)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("CLOSE & PREVIEW", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(ActivityModel rec) {
    return Container(
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
            color: const Color(0xFF4A00E0).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "ML ENGINE STATUS",
                style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 12),
                    SizedBox(width: 4),
                    Text("OPTIMIZED", style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            "RECOMMENDED TIER: ${rec.tier}",
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            "Based on your BMI, Trust Score (${widget.player.trustScore}), and Level (${widget.player.level}), our engine suggests ${rec.tier} level activity.",
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _headerStat("XP BOOST", "${(rec.xpMultiplier * 100).toInt()}%", Icons.bolt_rounded),
              _headerStat("RAID DMG", "${(rec.raidDamageMultiplier * 100).toInt()}%", Icons.gpp_good_rounded),
              _headerStat("MINS", "${rec.durationMinutes}m", Icons.timer_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.cyanAccent, size: 20),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PRIMARY FITNESS GOAL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white54, letterSpacing: 0.5)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _goalChip("weight_loss", "WEIGHT LOSS"),
              _goalChip("muscle_gain", "MUSCLE GAIN"),
              _goalChip("endurance", "ENDURANCE"),
              _goalChip("maintenance", "MAINTENANCE"),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("HEIGHT: ${_height.toStringAsFixed(0)} CM", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white54, letterSpacing: 0.5)),
                    Slider(
                      value: _height,
                      min: 120,
                      max: 220,
                      activeColor: Colors.cyanAccent,
                      inactiveColor: Colors.white10,
                      onChanged: (v) => setState(() => _height = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("WEIGHT: ${_weight.toStringAsFixed(1)} KG", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white54, letterSpacing: 0.5)),
                    Slider(
                      value: _weight,
                      min: 40,
                      max: 150,
                      activeColor: Colors.cyanAccent,
                      inactiveColor: Colors.white10,
                      onChanged: (v) => setState(() => _weight = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _goalChip(String id, String label) {
    bool selected = _goal == id;
    return GestureDetector(
      onTap: () => setState(() => _goal = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.cyanAccent : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(_kChipRadius),
          border: Border.all(color: selected ? Colors.cyanAccent : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white54,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTargetSliders() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("DAILY STEP TARGET", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white54, letterSpacing: 0.5)),
              Text(_stepTarget.toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.cyanAccent)),
            ],
          ),
          Slider(
            value: _stepTarget.toDouble(),
            min: 2000,
            max: 30000,
            divisions: 28,
            activeColor: Colors.cyanAccent,
            inactiveColor: Colors.white10,
            onChanged: (v) => setState(() => _stepTarget = v.toInt()),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("EXERCISE GOAL (MINS)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white54, letterSpacing: 0.5)),
              Text("${_exerciseTarget}M", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.cyanAccent)),
            ],
          ),
          Slider(
            value: _exerciseTarget.toDouble(),
            min: 10,
            max: 120,
            divisions: 11,
            activeColor: Colors.cyanAccent,
            inactiveColor: Colors.white10,
            onChanged: (v) => setState(() => _exerciseTarget = v.toInt()),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              foregroundColor: Colors.cyanAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
              ),
            ),
            onPressed: _applyRecommendation,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text("AUTO-APPLY ML RECOMMENDATION", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: _isSaving ? null : const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
            borderRadius: BorderRadius.circular(16),
            color: _isSaving ? Colors.white10 : null,
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isSaving ? null : _saveGoals,
            child: _isSaving 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text("DEPLOY UPDATED TARGETS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      ],
    );
  }

  Future<void> _saveGoals() async {
    setState(() => _isSaving = true);
    try {
      await FirebaseService().updateBiometrics(
        uid: widget.player.uid,
        heightCm: _height,
        weightKg: _weight,
        fitnessGoal: _goal,
        stepTarget: _stepTarget,
        exerciseTarget: _exerciseTarget,
        hourlySteps: _hourlySteps,
        dailyHistory: _dailyHistory,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("MISSION TARGETS UPDATED SUCCESSFULLY"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("ERROR: ${e.toString()}"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
