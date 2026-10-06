const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendPushOnNewNotification = functions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const recipientUid = context.params.userId;

    if (!data) return null;

    try {
      // 1. Recipient ka FCM Device Token Firestore se lein
      const userDoc = await admin.firestore().collection("users").doc(recipientUid).get();
      if (!userDoc.exists) return null;

      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) {
        console.log(`No FCM token found for user: ${recipientUid}`);
        return null;
      }

      const title = data.title || "Expense Tracker Alert";
      const message = data.message || "";
      const targetType = data.targetType || "group";
      const targetId = data.targetId || "";

      // 2. High-Priority FCM Payload jo band app ko OS level par jagayega
      const messagePayload = {
        token: fcmToken,
        notification: {
          title: title,
          body: message,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          targetType: targetType,
          targetId: targetId,
          title: title,
          body: message,
        },
        android: {
          priority: "high",
          notification: {
            channelId: "high_importance_channel",
            sound: "default",
            priority: "max",
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
      };

      // 3. Google Play Services ko push packet deliver karein
      const response = await admin.messaging().send(messagePayload);
      console.log(`Successfully sent push notification to ${recipientUid}:`, response);
      return response;
    } catch (error) {
      console.error("Error sending FCM notification:", error);
      return null;
    }
  });