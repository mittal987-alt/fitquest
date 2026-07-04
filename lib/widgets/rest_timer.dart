import 'dart:async';
import 'package:flutter/material.dart';

class RestTimer extends StatefulWidget {
  final int initialSeconds;
  final VoidCallback onTimerFinished;

  const RestTimer({
    super.key,
    required this.initialSeconds,
    required this.onTimerFinished
  });

  @override
  State<RestTimer> createState() => _RestTimerState();
}

class _RestTimerState extends State<RestTimer> {
  late Timer _timer;
  late int _currentSeconds;

  @override
  void initState() {
    super.initState();
    _currentSeconds = widget.initialSeconds;
    startTimer();
  }

  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentSeconds > 0) {
        setState(() => _currentSeconds--);
      } else {
        _timer.cancel();
        widget.onTimerFinished();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _currentSeconds > 0 ? Colors.amber.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            _currentSeconds > 0 ? "REST INTERVAL" : "RESUME ACTIVITY",
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            "$_currentSeconds",
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}