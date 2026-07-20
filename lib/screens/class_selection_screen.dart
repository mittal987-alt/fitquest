import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../config/game_theme.dart';
import 'main_navigation.dart';

class ClassSelectionScreen extends StatefulWidget {
  final String uid;

  const ClassSelectionScreen({super.key, required this.uid});

  @override
  State<ClassSelectionScreen> createState() => _ClassSelectionScreenState();
}

class _ClassSelectionScreenState extends State<ClassSelectionScreen> {
  final FirebaseService firebaseService = FirebaseService();
  String? selectedClass;
  bool loading = false;

  final List<Map<String, dynamic>> classes = [
    {
      'id': 'scout',
      'name': 'SCOUT',
      'icon': Icons.directions_run_rounded,
      'color': Colors.cyanAccent,
      'description': 'Fast and agile. Perfect for explorers who want to capture new areas easily.',
      'stats': {'STR': 8, 'AGI': 15, 'END': 10}
    },
    {
      'id': 'tank',
      'name': 'TANK',
      'icon': Icons.shield_rounded,
      'color': const Color(0xFFFF9800), // GameTheme.xp color
      'description': 'Strong and tough. Perfect for those who want more power and extra energy.',
      'stats': {'STR': 15, 'AGI': 8, 'END': 12}
    },
    {
      'id': 'medic',
      'name': 'MEDIC',
      'icon': Icons.health_and_safety_rounded,
      'color': Colors.greenAccent,
      'description': 'Steady and reliable. Perfect for staying active longer and recovering energy fast.',
      'stats': {'STR': 10, 'AGI': 10, 'END': 15}
    },
  ];

  Future<void> _handleSelection() async {
    if (selectedClass == null) return;

    setState(() => loading = true);
    try {
      await firebaseService.setCharacterClass(widget.uid, selectedClass!);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Deployment error: $e"), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "CHOOSE YOUR CLASS",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Pick the role that fits your playstyle. This sets your starting stats and special perks.",
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: classes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = classes[index];
                    final isSelected = selectedClass == item['id'];

                    return GestureDetector(
                      onTap: () => setState(() => selectedClass = item['id']),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? item['color'] : colorScheme.onSurface.withValues(alpha: 0.05),
                            width: 2,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: (item['color'] as Color).withValues(alpha: 0.1),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              )
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (item['color'] as Color).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item['icon'], color: item['color'], size: 30),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['name'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: 1,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['description'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: (item['stats'] as Map<String, int>).entries.map((e) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 12),
                                        child: Text(
                                          "${e.key}: ${e.value}",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: item['color'],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: selectedClass == null || loading 
                      ? null 
                      : const LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)]),
                  borderRadius: BorderRadius.circular(20),
                  color: selectedClass == null || loading ? colorScheme.onSurface.withValues(alpha: 0.1) : null,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: colorScheme.onPrimary,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  onPressed: selectedClass == null || loading ? null : _handleSelection,
                  child: loading
                      ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: colorScheme.onPrimary, strokeWidth: 2))
                      : const Text("START YOUR JOURNEY", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
