import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comeback_app/models/user_model.dart';
import 'package:comeback_app/models/connection_request.dart';
import 'package:comeback_app/models/page_alert.dart';
import 'package:comeback_app/models/chat_message.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');
  CollectionReference get _connectionRequests => _db.collection('connection_requests');
  CollectionReference get _pageAlerts => _db.collection('page_alerts');
  CollectionReference get _chatRooms => _db.collection('chat_rooms');

  // ── Users ──

  Future<void> createUser(AppUser user) {
    return _users.doc(user.uid).set(user.toMap());
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()! as Map<String, dynamic>);
  }

  Stream<AppUser?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromMap(doc.data()! as Map<String, dynamic>);
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _users.doc(uid).update(data);
  }

  Future<void> updateFcmToken(String uid, String token) {
    return _users.doc(uid).update({'fcmToken': token});
  }

  // ── Owner → Employees ──

  Stream<List<EmployeeUser>> getEmployees(String ownerUid) {
    return _users
        .where('role', isEqualTo: UserRole.employee.name)
        .where('connectedOwnerId', isEqualTo: ownerUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => EmployeeUser.fromMap(d.data()! as Map<String, dynamic>))
            .toList());
  }

  Future<void> removeEmployee(String ownerUid, String employeeUid) {
    return disconnect(ownerUid, employeeUid);
  }

  // ── Connection Requests ──

  Future<void> sendConnectionRequest(ConnectionRequest request) {
    return _connectionRequests.doc(request.id).set(request.toMap());
  }

  Stream<List<ConnectionRequest>> getConnectionRequests(String employeeId) {
    return _connectionRequests
        .where('toEmployeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ConnectionRequest.fromMap(
                d.data()! as Map<String, dynamic>,
                id: d.id))
            .toList());
  }

  Future<void> acceptConnection(String requestId, String ownerId, String employeeId) async {
    final batch = _db.batch();

    batch.update(_connectionRequests.doc(requestId), {'status': 'accepted'});
    batch.update(_users.doc(employeeId), {'connectedOwnerId': ownerId});
    batch.update(_users.doc(ownerId), {
      'employeeIds': FieldValue.arrayUnion([employeeId]),
    });

    await batch.commit();
  }

  Future<void> declineConnection(String requestId) {
    return _connectionRequests.doc(requestId).update({'status': 'declined'});
  }

  Future<EmployeeUser?> findEmployeeByCode(String code) async {
    final snap = await _users
        .where('role', isEqualTo: UserRole.employee.name)
        .where('connectionCode', isEqualTo: code)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return EmployeeUser.fromMap(snap.docs.first.data()! as Map<String, dynamic>);
  }

  // ── Disconnect ──

  Future<void> disconnect(String ownerId, String employeeId) async {
    final batch = _db.batch();

    batch.update(_users.doc(employeeId), {'connectedOwnerId': null});
    batch.update(_users.doc(ownerId), {
      'employeeIds': FieldValue.arrayRemove([employeeId]),
    });

    await batch.commit();
  }

  // ── Page Alerts ──

  Future<void> createPageAlert(PageAlert alert) {
    return _pageAlerts.doc(alert.id).set(alert.toMap());
  }

  Future<void> acknowledgePageAlert(String alertId) {
    return _pageAlerts.doc(alertId).update({
      'status': 'acknowledged',
      'acknowledgedAt': Timestamp.now(),
    });
  }

  Future<void> cancelPageAlert(String alertId) {
    return _pageAlerts.doc(alertId).update({'status': 'cancelled'});
  }

  Stream<PageAlert?> getActivePageForEmployee(String employeeId) {
    return _pageAlerts
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return PageAlert.fromMap(
          snap.docs.first.data()! as Map<String, dynamic>,
          id: snap.docs.first.id);
    });
  }

  // ── Chat (1:1) ──

  String getChatRoomId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<void> sendMessage(ChatMessage message) async {
    final roomId = message.chatRoomId;
    final roomRef = _chatRooms.doc(roomId);
    final msgRef = roomRef.collection('messages').doc(message.id);

    final batch = _db.batch();
    batch.set(roomRef, {
      'lastMessage': message.text,
      'lastMessageAt': Timestamp.fromDate(message.timestamp),
    }, SetOptions(merge: true));
    batch.set(msgRef, message.toMap());
    await batch.commit();
  }

  Stream<List<ChatMessage>> getMessages(String chatRoomId) {
    return _chatRooms
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatMessage.fromMap(d.data(), id: d.id))
            .toList());
  }

  // ── Group Chat ──

  String getGroupChatRoomId(String ownerId) => 'group_$ownerId';

  Stream<List<ChatMessage>> getGroupMessages(String ownerId) {
    return getMessages(getGroupChatRoomId(ownerId));
  }

  // ── Employee Status ──

  Future<void> updateEmployeeStatus(String uid, String status) {
    return _users.doc(uid).update({'status': status});
  }

  // ── Chat Rooms list for unread tracking ──

  Stream<Map<String, dynamic>?> getChatRoomMeta(String chatRoomId) {
    return _chatRooms.doc(chatRoomId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data() as Map<String, dynamic>?;
    });
  }
}
