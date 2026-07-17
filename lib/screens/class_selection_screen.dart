import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
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
      'color': Colors.orangeAccent,
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "CHOOSE YOUR CLASS",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                "Pick the role that fits your playstyle. This sets your starting stats and special perks.",
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.separated(
                  itemCount: classes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = classes[index];
                    final isSelected = selectedClass == item['id'];

                    return GestureDetector(
                      onTap: () => setState(() => selectedClass = item['id']),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161B22),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? item['color'] : Colors.white.withValues(alpha: 0.05),
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
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1, color: Colors.white),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['description'],
                                    style: const TextStyle(fontSize: 11, color: Colors.white54, height: 1.4),
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
                  color: selectedClass == null || loading ? Colors.white10 : null,
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  onPressed: selectedClass == null || loading ? null : _handleSelection,
                  child: loading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("START YOUR JOURNEY", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
