const functions = require('firebase-functions');
const admin = require('firebase-admin');
const os = require('os');
const path = require('path');
const fs = require('fs');
const { parse } = require('csv-parse/sync');

admin.initializeApp();

// Cloud Function to send scheduled push notifications
exports.sendScheduledNotification = functions.firestore
  .document('scheduledNotifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const { userId, title, body, scheduledTime, data, sent } = notification;

    // Skip if already sent
    if (sent) {
      console.log('Notification already sent, skipping...');
      return null;
    }

    // Check if it's time to send
    const now = admin.firestore.Timestamp.now();
    const scheduleTime = scheduledTime;

    if (scheduleTime.toMillis() > now.toMillis()) {
      console.log('Notification not yet ready to send, scheduling...');
      
      // Schedule this function to run when it's time
      const delay = scheduleTime.toMillis() - now.toMillis();
      
      // For delays less than 10 minutes, we can use Cloud Tasks or setTimeout
      if (delay < 10 * 60 * 1000) {
        setTimeout(async () => {
          await sendNotificationToUser(userId, title, body, data);
          await snap.ref.update({ sent: true, sentAt: admin.firestore.Timestamp.now() });
        }, delay);
      }
      
      return null;
    }

    // Send immediately if time has passed
    try {
      await sendNotificationToUser(userId, title, body, data);
      await snap.ref.update({ sent: true, sentAt: admin.firestore.Timestamp.now() });
      console.log('Notification sent successfully');
    } catch (error) {
      console.error('Error sending notification:', error);
    }

    return null;
  });

// Helper function to send notification to a user
async function sendNotificationToUser(userId, title, body, data) {
  try {
    // Get user's FCM token
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    const userData = userDoc.data();
    
    if (!userData || !userData.fcmToken) {
      console.log('No FCM token found for user:', userId);
      return;
    }

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      token: userData.fcmToken,
      android: {
        notification: {
          channelId: 'session_reminders_channel_id',
          priority: 'high',
          defaultSound: true,
          defaultVibrateTimings: true,
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          }
        }
      }
    };

    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
    return response;
  } catch (error) {
    console.error('Error sending message:', error);
    throw error;
  }
}

// Manual trigger for testing notifications
exports.testNotification = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { title, body } = data;
  const userId = context.auth.uid;

  try {
    await sendNotificationToUser(userId, title || 'Test Notification', body || 'This is a test push notification!', { type: 'test' });
    return { success: true, message: 'Test notification sent successfully' };
  } catch (error) {
    console.error('Test notification failed:', error);
    throw new functions.https.HttpsError('internal', 'Failed to send test notification');
  }
});

// Process scheduled notifications (runs every minute)
exports.processScheduledNotifications = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  const now = admin.firestore.Timestamp.now();
  
  // Query for notifications that are due to be sent
  const query = admin.firestore()
    .collection('scheduledNotifications')
    .where('sent', '==', false)
    .where('scheduledTime', '<=', now)
    .limit(50);

  const snapshot = await query.get();
  
  if (snapshot.empty) {
    console.log('No scheduled notifications to process');
    return null;
  }

  const batch = admin.firestore().batch();
  const notifications = [];

  snapshot.forEach(doc => {
    const notification = doc.data();
    notifications.push({ id: doc.id, ...notification });
    
    // Mark as sent in batch
    batch.update(doc.ref, { 
      sent: true, 
      sentAt: admin.firestore.Timestamp.now() 
    });
  });

  // Send all notifications
  const promises = notifications.map(notification => 
    sendNotificationToUser(notification.userId, notification.title, notification.body, notification.data)
  );

  try {
    await Promise.all(promises);
    await batch.commit();
    console.log(`Successfully sent ${notifications.length} scheduled notifications`);
  } catch (error) {
    console.error('Error processing scheduled notifications:', error);
  }

  return null;
});

// === Bulk import: Upload CSV to Cloud Storage at imports/{uid}/clients*.csv ===
// CSV headers supported (case-insensitive):
// ID, First Name, Last Name, Gender, DOB, Email, Phone, Occupation, Description
// If ID is omitted, IDs will be auto-assigned sequentially after the current max.
exports.importClientsCsv = functions.storage.object().onFinalize(async (object) => {
  try {
    const filePath = object.name || '';
    // Only handle files uploaded under imports/{uid}/ and ending with .csv
    if (!filePath.startsWith('imports/')) return null;
    const parts = filePath.split('/');
    if (parts.length < 3) return null;
    const uid = parts[1];
    const filename = parts[2] || '';
    if (!filename.toLowerCase().endsWith('.csv')) return null;

    const bucket = admin.storage().bucket(object.bucket);
    const tempFilePath = path.join(os.tmpdir(), path.basename(filePath));
    await bucket.file(filePath).download({ destination: tempFilePath });

    const content = fs.readFileSync(tempFilePath, 'utf8');
    // Parse CSV with header row into array of objects
    const rows = parse(content, {
      columns: true,
      skip_empty_lines: true,
      trim: true,
    });

    const db = admin.firestore();
    const userClientsCol = db.collection('users').doc(uid).collection('clients');

    // Determine current max ID to continue sequence if IDs are not provided
    const existingSnap = await userClientsCol.select('id').get();
    let maxId = 0;
    existingSnap.forEach((doc) => {
      const v = doc.get('id');
      if (typeof v === 'number' && v > maxId) maxId = v;
    });

    // Helper to read value by multiple possible header names
    const getVal = (row, keys) => {
      for (const k of keys) {
        if (row[k] !== undefined && row[k] !== null) return String(row[k]).trim();
      }
      return '';
    };

    let batch = db.batch();
    let ops = 0;
    let imported = 0;

    for (const row of rows) {
      // Flexible ID handling
      let idRaw = row['ID'] ?? row['Id'] ?? row['id'];
      let idNum = parseInt(idRaw, 10);
      if (!Number.isInteger(idNum)) {
        idNum = maxId + 1;
        maxId = idNum;
      }

      const clientData = {
        id: idNum,
        firstName: getVal(row, ['First Name', 'firstName', 'FirstName']),
        lastName: getVal(row, ['Last Name', 'lastName', 'LastName']),
        gender: getVal(row, ['Gender', 'gender']),
        dob: getVal(row, ['DOB', 'dob', 'Date of Birth', 'DateOfBirth']),
        email: getVal(row, ['Email', 'email']),
        phone: getVal(row, ['Phone', 'phone', 'Mobile']),
        occupation: getVal(row, ['Occupation', 'occupation']),
        description: getVal(row, ['Description', 'description', 'Notes']),
      };

      const ref = userClientsCol.doc(String(idNum));
      batch.set(ref, clientData, { merge: true });
      ops += 1;
      imported += 1;

      // Commit in chunks to avoid exceeding batch limits
      if (ops >= 400) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }

    if (ops > 0) {
      await batch.commit();
    }

    // Move processed file to a subfolder to avoid re-import loops
    const processedPath = `imports/${uid}/processed/${path.basename(filePath)}`;
    await bucket.file(filePath).move(processedPath);

    await db.collection('users').doc(uid).collection('import_logs').add({
      type: 'clients_csv',
      file: processedPath,
      total: rows.length,
      imported,
      at: admin.firestore.FieldValue.serverTimestamp(),
    });

    try { fs.unlinkSync(tempFilePath); } catch (_) {}

    console.log(`Imported ${imported}/${rows.length} clients for user ${uid} from ${filename}.`);
    return null;
  } catch (err) {
    console.error('importClientsCsv error:', err);
    // Ensure we don't crash the function in case of transient issues
    return null;
  }
});