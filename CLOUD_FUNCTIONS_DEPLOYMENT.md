# Cloud Functions Deployment Guide

## Overview
You need to deploy 3 Cloud Functions to Firebase to complete the notification system:
1. **Email Processor** - Sends queued emails
2. **Push Notification Delivery** - Sends push notifications via FCM
3. **OTP Cleanup** - Removes expired OTP tokens (optional but recommended)

---

## STEP 1: Install Firebase CLI

### Windows (PowerShell):
```powershell
# Install Node.js first from https://nodejs.org/ (LTS version)
# Then verify installation:
node --version
npm --version

# Install Firebase CLI globally:
npm install -g firebase-tools

# Verify installation:
firebase --version
```

### Verify:
```powershell
firebase login
# This will open a browser to authenticate with your Google account
```

---

## STEP 2: Initialize Cloud Functions in Your Project

Navigate to your project directory and set up functions:

```powershell
cd C:\COVY\mta_water_delivery

# Initialize Cloud Functions
firebase init functions

# When prompted:
# - Select your Firebase project from the list
# - Choose JavaScript (or TypeScript if preferred)
# - Install dependencies: Yes
```

This creates a `functions/` folder in your project.

---

## STEP 3: Create Email Processor Function

Create file: `functions/src/index.js` (or replace if it exists)

Replace the entire contents with:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();

// Configure nodemailer with your email service
// Option 1: Gmail (less secure, requires App Password)
// Option 2: SendGrid (recommended)
// Option 3: Firebase Email (if you have credentials)

// Example using Gmail App Password:
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER,      // Set in Firebase Console
    pass: process.env.EMAIL_PASSWORD,  // Set in Firebase Console
  }
});

// Example using SendGrid:
// const transporter = nodemailer.createTransport({
//   host: 'smtp.sendgrid.net',
//   port: 587,
//   auth: {
//     user: 'apikey',
//     pass: process.env.SENDGRID_API_KEY,
//   }
// });

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
        from: process.env.EMAIL_USER,
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
        // Re-trigger by creating a new document or updating status
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
```

---

## STEP 4: Install Dependencies

Edit `functions/package.json` to include nodemailer:

```json
{
  "name": "functions",
  "description": "Cloud Functions for MTA Water Delivery",
  "scripts": {
    "serve": "firebase emulators:start --only functions",
    "shell": "firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "18"
  },
  "main": "src/index.js",
  "dependencies": {
    "firebase-admin": "^11.8.0",
    "firebase-functions": "^4.3.1",
    "nodemailer": "^6.9.3"
  },
  "devDependencies": {
    "firebase-functions-test": "^3.1.0"
  },
  "private": true
}
```

Then install:
```powershell
cd functions
npm install
cd ..
```

---

## STEP 5: Set Environment Variables

### For Gmail (Less Secure):
```powershell
firebase functions:config:set gmail.user="your-email@gmail.com"
firebase functions:config:set gmail.password="your-app-password"
```

### For SendGrid (Recommended):
```powershell
firebase functions:config:set sendgrid.api_key="your-sendgrid-api-key"
```

Get your SendGrid API key from: https://app.sendgrid.com/settings/api_keys

---

## STEP 6: Deploy Cloud Functions

```powershell
firebase deploy --only functions
```

This will:
- Upload your functions to Firebase
- Deploy them automatically
- Show you the deployed function URLs

---

## STEP 7: Push Notification Cloud Function

Create another function file: `functions/src/notifications.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

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

      return { success: true, messageId: response };
    } catch (error) {
      console.error(`Error sending push notification:`, error);
      throw error;
    }
  });
```

Add this to `functions/src/index.js`:
```javascript
const notifications = require('./notifications');
exports.sendPushNotification = notifications.sendPushNotification;
```

---

## STEP 8: Test Locally (Optional)

Before deploying to production, test locally:

```powershell
cd functions
npm run serve
```

This starts the emulator where you can test functions.

---

## STEP 9: View Logs

Monitor your deployed functions:

```powershell
firebase functions:log
```

Or view in Firebase Console:
1. Go to Firebase Console → Functions
2. Click on your function
3. View logs in the "Logs" tab

---

## Testing the System

### Test Email Notifications:
1. In Firestore, create a test document in `emailQueue` collection:
```javascript
{
  recipientEmail: "your-email@example.com",
  subject: "Test Email",
  template: "order_confirmation",
  data: {
    customerName: "John",
    orderId: "ORD001",
    productType: "Water Gallons",
    quantity: 5,
    totalAmount: 500,
    address: "123 Main St, QC"
  },
  status: "pending",
  createdAt: timestamp
}
```

2. Watch as the function automatically processes it and changes status to "sent"

### Test Push Notifications:
1. Ensure user has FCM token saved in `users` collection
2. Create notification document in Firestore:
```javascript
{
  userId: "user-id",
  title: "Order Placed",
  body: "Your order has been confirmed",
  type: "order_placed",
  read: false,
  createdAt: timestamp
}
```

3. Watch for notification on user's device

---

## Troubleshooting

### Email not sending?
- Check Firebase Console → Functions → Logs
- Verify email credentials are correct
- Ensure Gmail: Allow less secure apps is enabled
- For SendGrid: Verify API key is valid

### Push notification not received?
- Verify FCM token is saved in database
- Check Firebase Console → Cloud Messaging settings
- Ensure Firebase Cloud Messaging API is enabled
- Test with Firebase Console → Cloud Messaging tab

### Function deployment failed?
- Check `firebase functions:log` for errors
- Verify `functions/package.json` is correct
- Run `npm install` in functions folder
- Check Node.js version: `node --version`

---

## Cost Considerations

Free tier includes:
- 125,000 function invocations per month
- 40,000 GiB-seconds of compute time

Most small to medium apps stay within free tier.

---

## Security Best Practices

1. **Never hardcode credentials** - Use environment variables
2. **Validate all inputs** - Check email format, data structure
3. **Rate limiting** - Add checks to prevent spam
4. **Error handling** - Don't expose sensitive info in logs
5. **Monitoring** - Set up alerts for function failures

---

## Next Steps After Deployment

1. Test all notification flows end-to-end
2. Monitor logs for errors
3. Set up alerts in Firebase Console
4. Schedule backups of Firestore
5. Plan for scaling (if needed)

Once Cloud Functions are deployed, your notification system will be 100% complete!
