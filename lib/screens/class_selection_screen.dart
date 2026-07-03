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
      'description': 'Specializes in agility and speed. +5 AGI base bonus. Reduced AP cost for capture actions.',
      'stats': {'STR': 8, 'AGI': 15, 'END': 10}
    },
    {
      'id': 'tank',
      'name': 'TANK',
      'icon': Icons.shield_rounded,
      'color': Colors.orangeAccent,
      'description': 'Built for endurance and raw power. +5 STR base bonus. Higher maximum stamina capacity.',
      'stats': {'STR': 15, 'AGI': 8, 'END': 12}
    },
    {
      'id': 'medic',
      'name': 'MEDIC',
      'icon': Icons.health_and_safety_rounded,
      'color': Colors.greenAccent,
      'description': 'Tactical support and rapid recovery. +5 END base bonus. Faster stamina regeneration.',
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
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "SELECT OPERATOR CLASS",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const Text(
                "Choose your tactical specialization to initialize base attribute vectors.",
                style: TextStyle(color: Colors.black45, fontSize: 13),
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected ? item['color'] : Colors.black.withValues(alpha: 0.05),
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
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['description'],
                                    style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.4),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  onPressed: selectedClass == null || loading ? null : _handleSelection,
                  child: loading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("INITIALIZE CLASS DATA", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
