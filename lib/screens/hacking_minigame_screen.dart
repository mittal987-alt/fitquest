import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HackingMinigameScreen extends StatefulWidget {
  final String eventId;
  final String teamId;
  final String uid;
  final Function(bool success) onComplete;

  const HackingMinigameScreen({
    super.key,
    required this.eventId,
    required this.teamId,
    required this.uid,
    required this.onComplete,
  });

  @override
  State<HackingMinigameScreen> createState() => _HackingMinigameScreenState();
}

class _HackingMinigameScreenState extends State<HackingMinigameScreen> {
  late List<String> grid;
  late List<String> targetSequence;
  List<int> selectedIndices = [];
  int timeLeft = 30;
  Timer? timer;
  bool isGameOver = false;
  bool isSuccess = false;

  final List<String> hexChars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'];

  @override
  void initState() {
    super.initState();
    _generateLevel();
    _startTimer();
  }

  void _generateLevel() {
    final random = Random();
    grid = List.generate(25, (index) => hexChars[random.nextInt(hexChars.length)] + hexChars[random.nextInt(hexChars.length)]);
    
    // Create a solvable target sequence from the grid
    targetSequence = [];
    int currentIdx = random.nextInt(25);
    for (int i = 0; i < 4; i++) {
      targetSequence.add(grid[currentIdx]);
      // Move to a random neighbor for the next part of the sequence to simulate a path
      List<int> neighbors = _getNeighbors(currentIdx);
      currentIdx = neighbors[random.nextInt(neighbors.length)];
    }
  }

  List<int> _getNeighbors(int index) {
    List<int> neighbors = [];
    int row = index ~/ 5;
    int col = index % 5;

    if (row > 0) neighbors.add(index - 5);
    if (row < 4) neighbors.add(index + 5);
    if (col > 0) neighbors.add(index - 1);
    if (col < 4) neighbors.add(index + 1);
    
    return neighbors;
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft > 0) {
        setState(() => timeLeft--);
      } else {
        _endGame(false);
      }
    });
  }

  void _onTileTap(int index) {
    if (isGameOver) return;

    setState(() {
      if (grid[index] == targetSequence[selectedIndices.length]) {
        selectedIndices.add(index);
        HapticFeedback.lightImpact();
        if (selectedIndices.length == targetSequence.length) {
          _endGame(true);
        }
      } else {
        // Reset progress on wrong tap
        selectedIndices.clear();
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _endGame(bool success) {
    timer?.cancel();
    setState(() {
      isGameOver = true;
      isSuccess = success;
    });
    
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        widget.onComplete(success);
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Spacer(),
            _buildTargetSequence(),
            const SizedBox(height: 32),
            _buildGrid(),
            const Spacer(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("BREACH PROTOCOL", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.w900, letterSpacing: 2)),
              Text("STATUS: ${isGameOver ? (isSuccess ? 'ACCESS GRANTED' : 'FAILED') : 'ACTIVE'}", 
                style: TextStyle(color: isGameOver ? (isSuccess ? Colors.greenAccent : Colors.redAccent) : Colors.white54, fontSize: 12)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: timeLeft < 10 ? Colors.redAccent : Colors.cyanAccent),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              "00:${timeLeft.toString().padLeft(2, '0')}",
              style: TextStyle(
                color: timeLeft < 10 ? Colors.redAccent : Colors.cyanAccent,
                fontFamily: 'Courier',
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSequence() {
    return Column(
      children: [
        const Text("REQUIRED SEQUENCE", style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(targetSequence.length, (index) {
            bool isFilled = selectedIndices.length > index;
            return Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: Border.all(color: isFilled ? Colors.cyanAccent : Colors.white10),
                color: isFilled ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: Text(
                targetSequence[index],
                style: TextStyle(
                  color: isFilled ? Colors.cyanAccent : Colors.white24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Courier',
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        border: Border.all(color: Colors.white10),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 25,
        itemBuilder: (context, index) {
          bool isSelected = selectedIndices.contains(index);
          return GestureDetector(
            onTap: () => _onTileTap(index),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: isSelected ? Colors.cyanAccent : Colors.white10),
                color: isSelected ? Colors.cyanAccent.withOpacity(0.2) : Colors.transparent,
              ),
              alignment: Alignment.center,
              child: Text(
                grid[index],
                style: TextStyle(
                  color: isSelected ? Colors.cyanAccent : Colors.white70,
                  fontFamily: 'Courier',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Text(
        "NETWORK NODE: ${widget.eventId.substring(0, 8).toUpperCase()}",
        style: const TextStyle(color: Colors.white12, fontSize: 10, fontFamily: 'Courier'),
      ),
    );
  }
}
