const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

exports.onPageAlertCreated = onDocumentCreated("page_alerts/{alertId}", async (event) => {
  const alert = event.data.data();
  if (alert.status !== "active") return;

  const employeeDoc = await db.collection("users").doc(alert.employeeId).get();
  if (!employeeDoc.exists) return;

  const employee = employeeDoc.data();
  const fcmToken = employee.fcmToken;
  if (!fcmToken) return;

  const ownerDoc = await db.collection("users").doc(alert.ownerId).get();
  const ownerName = ownerDoc.exists ? ownerDoc.data().businessName : "Your Boss";

  await messaging.send({
    token: fcmToken,
    notification: {
      title: "Come Back!",
      body: `${ownerName} is looking for you. Please come back to work.`,
    },
    data: {
      type: "page_alert",
      alertId: event.params.alertId,
      ownerId: alert.ownerId,
    },
    android: {
      priority: "high",
      notification: {
        channelId: "page_alerts",
        priority: "max",
        sound: "alarm",
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "alarm.caf",
          "interruption-level": "critical",
          badge: 1,
        },
      },
    },
  });
});

exports.onPageAlertCancelled = onDocumentUpdated("page_alerts/{alertId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();

  if (before.status === "active" && after.status === "cancelled") {
    const employeeDoc = await db.collection("users").doc(after.employeeId).get();
    if (!employeeDoc.exists) return;
    const fcmToken = employeeDoc.data().fcmToken;
    if (!fcmToken) return;

    await messaging.send({
      token: fcmToken,
      data: {
        type: "page_cancelled",
        alertId: event.params.alertId,
      },
      android: { priority: "high" },
    });
  }
});

exports.onChatMessage = onDocumentCreated("chat_rooms/{roomId}/messages/{messageId}", async (event) => {
  const message = event.data.data();
  const roomId = event.params.roomId;

  if (roomId.startsWith("group_")) {
    const ownerId = roomId.replace("group_", "");
    const ownerDoc = await db.collection("users").doc(ownerId).get();
    if (!ownerDoc.exists) return;
    const owner = ownerDoc.data();
    const employeeIds = owner.employeeIds || [];

    const allIds = [ownerId, ...employeeIds].filter(id => id !== message.senderId);

    for (const uid of allIds) {
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) continue;
      const token = userDoc.data().fcmToken;
      if (!token) continue;

      try {
        await messaging.send({
          token,
          notification: {
            title: `Team Chat - ${message.senderName}`,
            body: message.text,
          },
          data: { type: "group_chat", roomId },
          android: { priority: "high" },
        });
      } catch (e) {}
    }
  } else {
    const uids = roomId.split("_");
    const recipientId = uids.find(id => id !== message.senderId);
    if (!recipientId) return;

    const recipientDoc = await db.collection("users").doc(recipientId).get();
    if (!recipientDoc.exists) return;
    const token = recipientDoc.data().fcmToken;
    if (!token) return;

    try {
      await messaging.send({
        token,
        notification: {
          title: message.senderName,
          body: message.text,
        },
        data: { type: "private_chat", roomId },
        android: { priority: "high" },
      });
    } catch (e) {}
  }
});

exports.onConnectionRequest = onDocumentCreated("connection_requests/{requestId}", async (event) => {
  const request = event.data.data();
  const employeeDoc = await db.collection("users").doc(request.toEmployeeId).get();
  if (!employeeDoc.exists) return;
  const token = employeeDoc.data().fcmToken;
  if (!token) return;

  try {
    await messaging.send({
      token,
      notification: {
        title: "Connection Request",
        body: `${request.businessName} wants to connect with you.`,
      },
      data: { type: "connection_request", requestId: event.params.requestId },
      android: { priority: "high" },
    });
  } catch (e) {}
});
