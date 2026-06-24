const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();

// Send push notification when a page alert is created
exports.onPageAlertCreated = onDocumentCreated(
  "page_alerts/{alertId}",
  async (event) => {
    const alert = event.data.data();
    if (!alert || alert.status !== "active") return;

    const employeeDoc = await db.doc(`users/${alert.employeeId}`).get();
    if (!employeeDoc.exists) return;

    const employee = employeeDoc.data();
    const token = employee.fcmToken;
    if (!token) return;

    let ownerName = "Your Boss";
    if (alert.ownerId) {
      const ownerDoc = await db.doc(`users/${alert.ownerId}`).get();
      if (ownerDoc.exists) {
        ownerName = ownerDoc.data().businessName || ownerName;
      }
    }

    try {
      await messaging.send({
        token,
        notification: {
          title: "You're Being Paged!",
          body: `${ownerName} needs you right now!`,
        },
        data: {
          type: "page_alert",
          alertId: event.params.alertId,
          ownerId: alert.ownerId || "",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "page_alerts",
            priority: "max",
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              "content-available": 1,
            },
          },
          headers: {
            "apns-priority": "10",
          },
        },
      });
    } catch (err) {
      console.error("Failed to send page alert notification:", err);
    }
  }
);

// Send push notification when a chat message is created
exports.onChatMessageCreated = onDocumentCreated(
  "chat_rooms/{chatRoomId}/messages/{messageId}",
  async (event) => {
    const message = event.data.data();
    if (!message) return;

    const chatRoomId = event.params.chatRoomId;
    const senderId = message.senderId;

    // Determine recipient(s)
    const recipientIds = [];

    if (chatRoomId.startsWith("group_")) {
      // Group chat - notify all employees of the owner + owner if sender is employee
      const ownerId = chatRoomId.replace("group_", "");

      if (senderId === ownerId) {
        // Owner sent - notify all employees
        const employeesSnap = await db
          .collection("users")
          .where("role", "==", "employee")
          .where("connectedOwnerId", "==", ownerId)
          .get();
        employeesSnap.forEach((doc) => recipientIds.push(doc.id));
      } else {
        // Employee sent - notify owner + other employees
        recipientIds.push(ownerId);
        const employeesSnap = await db
          .collection("users")
          .where("role", "==", "employee")
          .where("connectedOwnerId", "==", ownerId)
          .get();
        employeesSnap.forEach((doc) => {
          if (doc.id !== senderId) recipientIds.push(doc.id);
        });
      }
    } else {
      // 1:1 chat - chatRoomId is "uid1_uid2" (sorted)
      const parts = chatRoomId.split("_");
      for (const uid of parts) {
        if (uid !== senderId) recipientIds.push(uid);
      }
    }

    if (recipientIds.length === 0) return;

    // Get sender name
    const senderDoc = await db.doc(`users/${senderId}`).get();
    let senderName = "Someone";
    if (senderDoc.exists) {
      const data = senderDoc.data();
      senderName = data.businessName || data.name || senderName;
    }

    const body = message.imageUrl
      ? `${senderName} sent a photo`
      : `${senderName}: ${(message.text || "").substring(0, 100)}`;

    const isGroup = chatRoomId.startsWith("group_");
    const title = isGroup ? "Group Chat" : "New Message";

    // Send to all recipients
    const sendPromises = recipientIds.map(async (recipientId) => {
      const recipientDoc = await db.doc(`users/${recipientId}`).get();
      if (!recipientDoc.exists) return;

      const token = recipientDoc.data().fcmToken;
      if (!token) return;

      try {
        await messaging.send({
          token,
          notification: { title, body },
          data: {
            type: "chat_message",
            chatRoomId,
            senderId,
          },
          android: {
            priority: "high",
            notification: {
              channelId: "default",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        });
      } catch (err) {
        console.error(`Failed to notify ${recipientId}:`, err);
      }
    });

    await Promise.all(sendPromises);
  }
);
