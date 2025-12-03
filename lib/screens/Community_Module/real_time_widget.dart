
// lib/screens/Community_Module/real_time_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';

class RealTimeTimestamp extends StatefulWidget {
  final DateTime timestamp;
  final TextStyle? style;

  const RealTimeTimestamp({
    super.key, 
    required this.timestamp,
    this.style,
  });

  @override
  State<RealTimeTimestamp> createState() => _RealTimeTimestampState();
}

class _RealTimeTimestampState extends State<RealTimeTimestamp> {
  Timer? _timer;
  String _displayText = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    // Update every minute (you can change this to seconds if you want)
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _updateTime();
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Stop the timer when widget is removed
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    final difference = now.difference(widget.timestamp);
    
    String newText;

    if (difference.inSeconds < 60) {
      newText = 'Just now';
    } else if (difference.inMinutes < 60) {
      newText = '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      newText = '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      newText = '${difference.inDays}d';
    } else {
      // If older than a week, show date (optional)
      newText = '${widget.timestamp.day}/${widget.timestamp.month}';
    }

    if (newText != _displayText) {
      setState(() {
        _displayText = newText;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      style: widget.style,
    );
  }
}