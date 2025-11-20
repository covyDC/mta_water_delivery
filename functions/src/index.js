const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Configure nodemailer - Using SendGrid (change as needed)
const transporter = nodemailer.createTransport({
  host: 'smtp.sendgrid.net',
  port: 587,
  auth: {
    user: 'apikey',
    pass: process.env.SENDGRID_API_KEY || 'your-sendgrid-api-key',
  }
});

/**
 * Email Processor Function
 * Triggered when a new email is added to emailQueue collection
 */
exports.processEmailQueue = functions.firestore
  .document('emailQueue/{emailId}')
  .onCreate(async (snap, context) => {
    const emailData = snap.data();
    const emailId = snap.id;

    try {
      // Validate email data
      if (!emailData.recipientEmail || !emailData.subject) {
        throw new Error('Missing required fields: recipientEmail, subject');
      }

      // Build email body based on template
      const emailBody = buildEmailBody(emailData);

      // Send email
      const result = await transporter.sendMail({
        from: process.env.EMAIL_USER || 'noreply@mtawaterdelivery.com',
        to: emailData.recipientEmail,
        subject: emailData.subject,
        html: emailBody,
      });

      // Mark as sent in database
      await db.collection('emailQueue').doc(emailId).update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: result.messageId,
      });

      console.log(`Email sent successfully: ${emailId}`);
      return { success: true, messageId: result.messageId };
    } catch (error) {
      console.error(`Error sending email ${emailId}:`, error);

      // Mark as failed with retry count
      const currentRetries = emailData.retries || 0;
      if (currentRetries < 3) {
        await db.collection('emailQueue').doc(emailId).update({
          status: 'failed',
          retries: currentRetries + 1,
          lastError: error.message,
          lastAttempt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } else {
        // Max retries reached
        await db.collection('emailQueue').doc(emailId).update({
          status: 'failed_permanent',
          error: error.message,
        });
      }

      throw error;
    }
  });

/**
 * Helper function to build email HTML body based on template
 */
function buildEmailBody(emailData) {
  const { template, data } = emailData;

  switch (template) {
    case 'order_confirmation':
      return `
        <h2>Order Confirmation</h2>
        <p>Hi ${data.customerName},</p>
        <p>Your order #${data.orderId} has been confirmed!</p>
        <p><strong>Details:</strong></p>
        <ul>
          <li>Product: ${data.productType}</li>
          <li>Quantity: ${data.quantity}</li>
          <li>Total: ₱${data.totalAmount}</li>
          <li>Delivery Address: ${data.address}</li>
        </ul>
        <p>We'll notify you when your order is on the way.</p>
        <p>Thank you for your order!</p>
      `;

    case 'delivery_status':
      return `
        <h2>Delivery Update</h2>
        <p>Hi ${data.customerName},</p>
        <p>Your delivery is now <strong>${data.status}</strong>!</p>
        <p>Order: #${data.orderId}</p>
        <p>Estimated arrival: ${data.estimatedTime}</p>
        <p>Delivery address: ${data.address}</p>
      `;

    case 'delivery_completed':
      return `
        <h2>Delivery Completed</h2>
        <p>Hi ${data.customerName},</p>
        <p>Your order #${data.orderId} has been delivered!</p>
        <p>Thank you for using our service.</p>
      `;

    case 'admin_alert':
      return `
        <h2>Admin Alert</h2>
        <p>Alert Type: ${data.alertType}</p>
        <p>Details: ${JSON.stringify(data.alertData)}</p>
        <p>Time: ${new Date().toLocaleString()}</p>
      `;

    case 'otp_code':
      return `
        <h2>Your 2FA Code</h2>
        <p>Your one-time password is:</p>
        <h3 style="font-size: 32px; letter-spacing: 5px;">${data.otp}</h3>
        <p>This code expires in ${data.expiresIn}.</p>
        <p>If you didn't request this, please ignore this email.</p>
      `;

    default:
      return `<p>${data.message || 'Email from MTA Water Delivery'}</p>`;
  }
}

/**
 * OTP Cleanup Function
 * Runs daily at 2 AM to remove expired OTP tokens
 */
exports.cleanupExpiredOTPs = functions.pubsub
  .schedule('0 2 * * *') // Daily at 2 AM
  .timeZone('Asia/Manila')
  .onRun(async (context) => {
    try {
      const now = new Date();
      const snapshot = await db.collection('otpTokens')
        .where('expiresAt', '<', now)
        .limit(1000) // Process in batches
        .get();

      let deleted = 0;
      const batch = db.batch();

      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
        deleted++;
      });

      if (deleted > 0) {
        await batch.commit();
        console.log(`Deleted ${deleted} expired OTP tokens`);
      }

      return { success: true, deleted };
    } catch (error) {
      console.error('Error cleaning up OTP tokens:', error);
      throw error;
    }
  });

/**
 * Retry Failed Emails Function
 * Runs daily to retry failed emails
 */
exports.retryFailedEmails = functions.pubsub
  .schedule('30 2 * * *') // Daily at 2:30 AM
  .timeZone('Asia/Manila')
  .onRun(async (context) => {
    try {
      const snapshot = await db.collection('emailQueue')
        .where('status', '==', 'failed')
        .where('retries', '<', 3)
        .limit(100)
        .get();

      let retried = 0;

      for (const doc of snapshot.docs) {
        // Re-trigger by updating status back to pending
        await doc.ref.update({
          status: 'pending',
          retries: admin.firestore.FieldValue.increment(1),
        });
        retried++;
      }

      console.log(`Scheduled retry for ${retried} failed emails`);
      return { success: true, retried };
    } catch (error) {
      console.error('Error retrying failed emails:', error);
      throw error;
    }
  });

/**
 * Push Notification Function
 * Triggered when a new notification is created
 */
exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notifData = snap.data();
    const userId = notifData.userId;

    try {
      // Get user's FCM token
      const userDoc = await db.collection('users').doc(userId).get();
      const fcmToken = userDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for user ${userId}`);
        return { success: false, reason: 'No FCM token' };
      }

      // Send notification via FCM
      const message = {
        notification: {
          title: notifData.title,
          body: notifData.body,
        },
        data: {
          notificationId: snap.id,
          type: notifData.type,
        },
        token: fcmToken,
      };

      const response = await admin.messaging().send(message);
      console.log(`Notification sent successfully:`, response);

      // Mark notification as sent
      await snap.ref.update({
        sentViaFCM: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, messageId: response };
    } catch (error) {
      console.error(`Error sending push notification:`, error);
      throw error;
    }
  });

/**
 * Daily Report Generator Function
 * Runs daily at 6 PM to generate and email reports
 */
exports.generateDailyReports = functions.pubsub
  .schedule('0 18 * * *') // Daily at 6 PM
  .timeZone('Asia/Manila')
  .onRun(async (context) => {
    try {
      const today = new Date();
      const startOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate());
      const endOfDay = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);

      // Get today's orders
      const ordersSnapshot = await db.collection('orders')
        .where('createdAt', '>=', startOfDay)
        .where('createdAt', '<', endOfDay)
        .get();

      // Get today's deliveries
      const deliveriesSnapshot = await db.collection('deliveries')
        .where('createdAt', '>=', startOfDay)
        .where('createdAt', '<', endOfDay)
        .get();

      const orderCount = ordersSnapshot.size;
      const deliveryCount = deliveriesSnapshot.size;

      // Calculate total sales
      let totalSales = 0;
      ordersSnapshot.docs.forEach(doc => {
        totalSales += (doc.data().totalAmount || 0);
      });

      // Get all admin emails
      const adminsSnapshot = await db.collection('users')
        .where('role', '==', 'admin')
        .get();

      const reportData = {
        date: today.toLocaleDateString('en-PH'),
        orders: orderCount,
        deliveries: deliveryCount,
        totalSales: totalSales,
        averageOrderValue: orderCount > 0 ? (totalSales / orderCount).toFixed(2) : 0,
      };

      // Send report to each admin
      for (const adminDoc of adminsSnapshot.docs) {
        const admin = adminDoc.data();
        await db.collection('emailQueue').add({
          recipientEmail: admin.email,
          subject: `Daily Report - ${reportData.date}`,
          template: 'daily_report',
          data: reportData,
          status: 'pending',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      console.log(`Generated daily report for ${reportData.date}`);
      return { success: true, adminsNotified: adminsSnapshot.size };
    } catch (error) {
      console.error('Error generating daily reports:', error);
      throw error;
    }
  });
