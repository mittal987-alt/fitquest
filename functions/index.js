const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

/**
 * Triggers when a territory (hex_tile) is updated.
 * If the power decreases, it sends a notification to the owner.
 */
exports.onTerritoryAttack = functions.firestore
    .document("hex_tiles/{tileId}")
    .onUpdate(async (change, context) => {
      const beforeData = change.before.data();
      const afterData = change.after.data();

      // Check if power decreased (indicating an attack)
      if (afterData.power < beforeData.power) {
        const ownerId = afterData.ownerId;
        const ownerType = afterData.ownerType;
        const tileId = context.params.tileId;

        const payload = {
          notification: {
            title: "Territory Under Attack!",
            body: `Your territory ${tileId} is losing power!`,
            clickAction: "FLUTTER_NOTIFICATION_CLICK",
          },
          data: {
            tileId: tileId,
            type: "attack",
          },
        };

        if (ownerType === "solo") {
          // Send to specific player
          const userDoc = await admin.firestore().collection("players").doc(ownerId).get();
          if (userDoc.exists) {
            const fcmToken = userDoc.data().fcmToken;
            if (fcmToken) {
              await admin.messaging().sendToDevice(fcmToken, payload);
              console.log(`Attack notification sent to user ${ownerId}`);
            }
          }
        } else if (ownerType === "team") {
          // Send to team topic
          // Note: Users should be subscribed to "team_{teamId}" topic in Flutter
          const topic = `team_${ownerId}`;
          await admin.messaging().sendToTopic(topic, payload);
          console.log(`Attack notification sent to topic ${topic}`);
        }
      }
      return null;
    });

/**
 * Triggers when a territory is captured (created or owner changed).
 */
exports.onTerritoryCapture = functions.firestore
    .document("hex_tiles/{tileId}")
    .onWrite(async (change, context) => {
      // If it's a deletion, do nothing
      if (!change.after.exists) return null;

      const beforeData = change.before.exists ? change.before.data() : null;
      const afterData = change.after.data();

      // If owner changed (Capture)
      if (!beforeData || beforeData.ownerId !== afterData.ownerId) {
        if (beforeData) {
          // Notify previous owner they lost the territory
          const lostPayload = {
            notification: {
              title: "Territory Lost!",
              body: `Your territory ${context.params.tileId} was captured by ${afterData.ownerName}!`,
            },
          };

          if (beforeData.ownerType === "solo") {
            const prevUserDoc = await admin.firestore().collection("players").doc(beforeData.ownerId).get();
            if (prevUserDoc.exists && prevUserDoc.data().fcmToken) {
              await admin.messaging().sendToDevice(prevUserDoc.data().fcmToken, lostPayload);
            }
          } else {
            const topic = `team_${beforeData.ownerId}`;
            await admin.messaging().sendToTopic(topic, lostPayload);
          }
        }
      }
      return null;
    });
