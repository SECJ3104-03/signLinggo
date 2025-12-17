// lib/screens/Community_Module/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'comment_data.dart';
import 'post_data.dart';
import 'notification_data.dart'; 

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ================= NOTIFICATIONS =================

  Future<void> sendNotification({
    required String recipientId,
    required String type, 
    String? postId,
    String? message,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    if (currentUser.uid == recipientId) return; 

    try {
      String senderName = currentUser.displayName ?? 'Anonymous';
      if (senderName.isEmpty && currentUser.email != null) {
        senderName = currentUser.email!.split('@')[0];
      }
      String initials = senderName.isNotEmpty ? senderName[0].toUpperCase() : '?';

      final notif = NotificationData(
        recipientId: recipientId,
        senderName: senderName,
        senderInitials: initials,
        type: type,
        postId: postId,
        previewText: message,
        timestamp: DateTime.now(),
        isRead: false,
      );

      await _db.collection('notifications').add(notif.toMap());
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  Stream<List<NotificationData>> getNotificationsStream() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return const Stream.empty();

    return _db
        .collection('notifications')
        .where('recipientId', isEqualTo: myUid)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return NotificationData.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Future<void> markAllNotificationsAsRead() async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;

    try {
      final querySnapshot = await _db
          .collection('notifications')
          .where('recipientId', isEqualTo: myUid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print("Error marking all read: $e");
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      print("Error marking read: $e");
    }
  }

  // ================= COMMENTS (UPDATED WITH TRANSACTIONS) =================

  Future<void> addComment({
    required String postId, 
    required String postAuthorId, 
    required CommentData comment,
    String? replyToUserId,
  }) async {
    final postRef = _db.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(); // Auto-gen ID

    try {
      // Use a transaction to ensure atomic updates
      await _db.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        
        if (!postSnapshot.exists) {
          throw Exception("Post does not exist!");
        }

        // 1. Add the comment
        transaction.set(commentRef, comment.toMap());

        // 2. Increment the count safely based on current value
        int currentCount = postSnapshot.data()?['commentCount'] ?? 0;
        transaction.update(postRef, {'commentCount': currentCount + 1});
      });

      // Notifications can happen outside the transaction (non-critical)
      if (replyToUserId != null && replyToUserId.isNotEmpty) {
        await sendNotification(
          recipientId: replyToUserId,
          type: 'comment', 
          postId: postId,
          message: 'Replied: "${comment.content}"',
        );
      } else {
        await sendNotification(
          recipientId: postAuthorId,
          type: 'comment',
          postId: postId,
          message: comment.content,
        );
      }
      
    } catch (e) {
      print("Error adding comment: $e");
      rethrow; // Rethrow so UI knows it failed
    }
  }

  Future<void> deleteComment(String postId, String commentId) async {
    final postRef = _db.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc(commentId);

    try {
      await _db.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        
        // 1. Delete the comment
        transaction.delete(commentRef);

        // 2. Decrement count safely
        if (postSnapshot.exists) {
          int currentCount = postSnapshot.data()?['commentCount'] ?? 0;
          if (currentCount > 0) {
            transaction.update(postRef, {'commentCount': currentCount - 1});
          }
        }
      });

    } catch (e) {
      print("Error deleting comment: $e");
    }
  }

  Future<void> updatePostCommentCount(String postId, int newCount) async {
    // This is the "fixer" function called by PostDetailScreen if needed
    try {
      await _db.collection('posts').doc(postId).update({
        'commentCount': newCount,
      });
    } catch (e) {
      print("Error updating comment count: $e");
    }
  }

  Stream<List<CommentData>> getCommentsStream(String postId) {
    final String currentUserId = _auth.currentUser?.uid ?? '';

    return _db
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return CommentData.fromMap(doc.data(), doc.id, currentUserId);
      }).toList();
    });
  }

  Future<void> toggleCommentLike({
    required String postId, 
    required String commentId, 
    required String commentAuthorId,
    required bool isLiked,
  }) async {
    final String currentUserId = _auth.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    try {
      final docRef = _db
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);

      if (isLiked) {
        await docRef.update({
          'likedBy': FieldValue.arrayRemove([currentUserId]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await docRef.update({
          'likedBy': FieldValue.arrayUnion([currentUserId]),
          'likeCount': FieldValue.increment(1),
        });

        await sendNotification(
          recipientId: commentAuthorId,
          type: 'comment_like', 
          postId: postId,
          message: 'Liked your comment',
        );
      }
    } catch (e) {
      print("Error toggling comment like: $e");
    }
  }

  // ================= POSTS =================

  Stream<List<PostData>> getPostsStream() {
    final String currentUserId = _auth.currentUser?.uid ?? '';

    return _db.collection('posts')
      .orderBy('timestamp', descending: true) 
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          return PostData.fromMap(doc.data(), doc.id, currentUserId);
        }).toList();
      });
  }

  Future<void> togglePostLike(String postId, String postAuthorId, bool isLiked, int currentLikes) async {
    final String currentUserId = _auth.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    try {
      if (isLiked) {
        await _db.collection('posts').doc(postId).update({
          'likedBy': FieldValue.arrayRemove([currentUserId]),
          'likes': FieldValue.increment(-1),
        });
      } else {
        await _db.collection('posts').doc(postId).update({
          'likedBy': FieldValue.arrayUnion([currentUserId]),
          'likes': FieldValue.increment(1),
        });

        await sendNotification(
          recipientId: postAuthorId,
          type: 'like', 
          postId: postId,
          message: 'Liked your post',
        );
      }
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

  Future<void> togglePostFollow(String postId, String postAuthorId, bool isFollowed) async {
    final String currentUserId = _auth.currentUser?.uid ?? '';
    if (currentUserId.isEmpty) return;

    try {
      if (isFollowed) {
        await _db.collection('posts').doc(postId).update({
          'followers': FieldValue.arrayRemove([currentUserId]),
        });
      } else {
        await _db.collection('posts').doc(postId).update({
          'followers': FieldValue.arrayUnion([currentUserId]),
        });

        await sendNotification(
          recipientId: postAuthorId,
          type: 'follow',
          postId: postId, 
          message: 'Started following you',
        );
      }
    } catch (e) {
      print("Error toggling follow: $e");
    }
  }
}