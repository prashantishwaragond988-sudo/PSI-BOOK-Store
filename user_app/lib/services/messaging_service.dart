import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MessagingService {
  final _messaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await _messaging.requestPermission();
    final token = await _messaging.getToken();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (token != null && uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'fcm_token': token},
        SetOptions(merge: true),
      );
    }
  }
}
