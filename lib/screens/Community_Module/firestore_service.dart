// lib/screens/Community_Module/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'comment_data.dart';
import 'post_data.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================= COMMENTS =================

  Future<void> addComment(String postId, CommentData comment) async {
    try {
      await _db
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .add(comment.toMap());

      await _db.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(1),
      });
      
    } catch (e) {
      print("Error adding comment: $e");
    }
  }

  Future<void> deleteComment(String postId, String commentId) async {
    try {
      await _db
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();
          
      // Decrement, but we can't easily check for < 0 here in a simple call.
      // The UI logic and the sync logic in DetailScreen will handle cleanup.
      await _db.collection('posts').doc(postId).update({
        'commentCount': FieldValue.increment(-1),
      });

    } catch (e) {
      print("Error deleting comment: $e");
    }
  }

  // --- NEW: FORCE UPDATE COUNT (Repair function) ---
  Future<void> updatePostCommentCount(String postId, int newCount) async {
    try {
      await _db.collection('posts').doc(postId).update({
        'commentCount': newCount,
      });
    } catch (e) {
      print("Error updating comment count: $e");
    }
  }

  // ... (Paste the rest: getCommentsStream, toggleCommentLike, getPostsStream, togglePostLike, createPost, deletePost)
  
  Stream<List<CommentData>> getCommentsStream(String postId) {
    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CommentData.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> toggleCommentLike(String postId, String commentId, bool isLiked, int currentCount) async {
    try {
      final docRef = _db
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      final int newCount = isLiked ? (currentCount - 1) : (currentCount + 1);
      
      await docRef.update({
        'isLiked': !isLiked, 
        'likeCount': newCount < 0 ? 0 : newCount, 
      });
    } catch (e) {
      print("Error toggling comment like: $e");
    }
  }

  Stream<List<PostData>> getPostsStream() {
    return _db.collection('posts')
      .orderBy('timestamp', descending: true) 
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          return PostData.fromMap(doc.data(), doc.id);
        }).toList();
      });
  }

  Future<void> togglePostLike(String postId, bool isLiked, int currentLikes) async {
    try {
      final int newCount = isLiked ? (currentLikes - 1) : (currentLikes + 1);
      
      await _db.collection('posts').doc(postId).update({
        'isLiked': !isLiked,
        'likes': newCount < 0 ? 0 : newCount,
      });
    } catch (e) {
      print("Error toggling post like: $e");
    }
  }

  Future<void> createPost(PostData post) async {
    try {
      await _db.collection('posts').doc(post.id).set(post.toMap());
    } catch (e) {
      print("Error creating post: $e");
    }
  }
  
  Future<void> deletePost(String postId) async {
    try {
      await _db.collection('posts').doc(postId).delete();
    } catch (e) {
      print("Error deleting post: $e");
    }
  }

  // 9. TOGGLE FOLLOW STATUS
  Future<void> togglePostFollow(String postId, bool isFollowed) async {
    try {
      // If currently true, make it false. If false, make it true.
      await _db.collection('posts').doc(postId).update({
        'isFollowed': !isFollowed,
      });
    } catch (e) {
      print("Error toggling follow: $e");
    }
  }
}