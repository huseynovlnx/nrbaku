const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// ── Helper: FCM token-i users/{uid} sənədindən oxu ─────────────────
async function getFcmToken(uid) {
  const doc = await db.collection("users").doc(uid).get();
  if (!doc.exists) return null;
  return doc.data().fcmToken || null;
}

// ── 1) Təcili Çağırış trigger ──────────────────────────────────────
exports.onUrgentCallCreate = functions.firestore
  .document("urgentCalls/{deviceUid}/items/{callId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const deviceUid = context.params.deviceUid;
    const callId = context.params.callId;

    if (data.status !== "pending") return;

    const token = await getFcmToken(deviceUid);
    if (!token) {
      console.log(`No FCM token for device ${deviceUid}`);
      return;
    }

    const message = {
      token: token,
      data: {
        type: "urgent_call",
        callId: callId,
        deviceUid: deviceUid,
        fromUid: data.fromUid || "",
        fromName: data.fromName || "Admin",
        message: data.message || "Təcili çağırış!",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "nrbaku_urgent",
          priority: "max",
        },
      },
    };

    try {
      await messaging.send(message);
      console.log(`Urgent call sent to ${deviceUid}, callId: ${callId}`);
    } catch (error) {
      console.error("Error sending urgent call:", error);
      if (error.code === "messaging/registration-token-not-registered") {
        await db.collection("users").doc(deviceUid).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    }
  });

// ── 2) Admin Chat trigger ──────────────────────────────────────────
exports.onAdminChatMessage = functions.firestore
  .document("adminChats/{deviceUid}/messages/{msgId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const deviceUid = context.params.deviceUid;

    if (data.isFromAdmin !== true) return;

    const token = await getFcmToken(deviceUid);
    if (!token) {
      console.log(`No FCM token for device ${deviceUid}`);
      return;
    }

    const message = {
      token: token,
      data: {
        type: "admin_chat",
        deviceUid: deviceUid,
        title: "NrBaku — Admin",
        body: data.text || "Yeni mesaj",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "nrbaku_main",
          priority: "high",
        },
      },
    };

    try {
      await messaging.send(message);
      console.log(`Chat notification sent to ${deviceUid}`);
    } catch (error) {
      console.error("Error sending chat notification:", error);
      if (error.code === "messaging/registration-token-not-registered") {
        await db.collection("users").doc(deviceUid).update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    }
  });

// ── 3) Təcili Çağırış Cavab trigger ───────────────────────────────
exports.onUrgentCallResponded = functions.firestore
  .document("urgentCalls/{deviceUid}/items/{callId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const deviceUid = context.params.deviceUid;

    if (before.status === "pending" && after.status === "responded") {
      const adminSnap = await db
        .collection("adminAccess")
        .doc("config")
        .get();
      
      if (!adminSnap.exists) return;
      
      const adminUids = adminSnap.data().adminUids || [];
      
      for (const adminUid of adminUids) {
        const token = await getFcmToken(adminUid);
        if (!token) continue;

        const message = {
          token: token,
          data: {
            type: "urgent_call_responded",
            deviceUid: deviceUid,
            callId: context.params.callId,
            fromName: after.fromName || "Cihaz",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "nrbaku_main",
              priority: "high",
            },
          },
        };

        try {
          await messaging.send(message);
          console.log(`Response notification sent to admin ${adminUid}`);
        } catch (error) {
          console.error("Error sending response notification:", error);
        }
      }
    }
  });