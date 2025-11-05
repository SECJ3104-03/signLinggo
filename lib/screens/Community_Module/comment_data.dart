// lib/screens/Community_Module/comment_data.dart

import 'package:flutter/material.dart';

class CommentData {
  final String author;
  final String initials;
  final String content;

  const CommentData({
    required this.author,
    required this.initials,
    required this.content,
  });
}