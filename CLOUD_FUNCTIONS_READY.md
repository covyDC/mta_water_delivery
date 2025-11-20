# Cloud Functions Setup - COMPLETE ✓

## Summary

I've set up all your Cloud Functions code and installed all dependencies. Everything is ready to deploy!

## Files Created

### `/functions/package.json` 
- Contains all npm dependencies (firebase-admin, firebase-functions, nodemailer)
- All 565 packages installed successfully

### `/functions/src/index.js`
- **processEmailQueue** - Processes queued emails and sends them
- **cleanupExpiredOTPs** - Runs daily at 2 AM to remove expired OTP tokens
- **retryFailedEmails** - Runs daily at 2:30 AM to retry failed emails
- **sendPushNotification** - Triggers when new notification created, sends via FCM
- **generateDailyReports** - Runs daily at 6 PM, generates reports for admins

### `firebase.json` (Updated)
- Added functions configuration section
- Fixed JSON syntax issues

### `.firebaserc`
- Project linked to: `mta-water-delivery-8697f`

---

## What You Need to Do

### 1. Upgrade Firebase Project to Blaze Plan

Your Firebase project currently uses the free Spark plan, which doesn't support Cloud Functions. You need to upgrade.

**Easy upgrade:**
```
https://console.firebase.google.com/project/mta-water-delivery-8697f/usage/details
```

Click "Upgrade to Blaze" and add a payment method. Cost: Usually FREE (stays within free tier).

### 2. Set Up Email Service

Choose one:

**SendGrid (Recommended):**
```powershell
firebase functions:config:set sendgrid.api_key="sk-your-key-here"
```

**Gmail:**
```powershell
firebase functions:config:set gmail.email="your-email@gmail.com"
firebase functions:config:set gmail.password="your-app-password"
```

### 3. Deploy

```powershell
cd C:\COVY\mta_water_delivery
firebase deploy --only functions
```

---

## Function Details

### processEmailQueue
- **Triggered by:** New document in `emailQueue` collection
- **Does:** Sends email via SendGrid/Gmail
- **Retries:** Up to 3 times on failure
- **Status updates:** Sets status to "sent", "failed", or "failed_permanent"

### sendPushNotification
- **Triggered by:** New document in `notifications` collection
- **Does:** Sends push notification via Firebase Cloud Messaging (FCM)
- **Requires:** User has FCM token in Firestore
- **Data:** Includes title, body, and notification type

### cleanupExpiredOTPs
- **Runs:** Daily at 2:00 AM (Asia/Manila time)
- **Does:** Deletes all expired OTP tokens from `otpTokens` collection
- **Schedule:** Automated, no manual trigger needed

### retryFailedEmails
- **Runs:** Daily at 2:30 AM (Asia/Manila time)
- **Does:** Retries emails with status="failed" and retries < 3
- **Schedule:** Automated, no manual trigger needed

### generateDailyReports
- **Runs:** Daily at 6:00 PM (Asia/Manila time)
- **Does:** Creates daily summary and emails to all admins
- **Data:** Order count, delivery count, total sales, average order value

---

## After Deployment: Testing

### Test Email Notifications

1. Go to Firestore Console
2. Create new document in `emailQueue` collection:
   ```
   {
     "recipientEmail": "test@example.com",
     "subject": "Test Email",
     "template": "order_confirmation",
     "data": {
       "customerName": "John",
       "orderId": "ORD001",
       "productType": "Water",
       "quantity": 5,
       "totalAmount": 500,
       "address": "123 Main St"
     },
     "status": "pending",
     "createdAt": <timestamp>
   }
   ```

3. Check Cloud Functions logs:
   ```powershell
   firebase functions:log
   ```

4. Status should change to "sent" within seconds

### Test Push Notifications

1. User must have FCM token in `users/{userId}` (set when app opens)
2. Create document in `notifications` collection:
   ```
   {
     "userId": "user-id",
     "title": "Order Placed",
     "body": "Your order has been confirmed",
     "type": "order_placed",
     "read": false,
     "createdAt": <timestamp>
   }
   ```

3. Notification appears on user's device (if app installed)

---

## Cost Estimate

**Firebase Blaze Free Tier includes:**
- 2 million function invocations/month
- 400,000 GB-seconds of compute
- 5 GB Cloud Storage

**Typical Water Delivery App:**
- ~100 orders/day = 3,000 invocations/month
- **Estimated cost: $0 (stays in free tier)**

You only pay if you exceed free tier limits. Average cost for active apps: $1-5/month.

---

## Important Files to Keep

```
functions/
├── package.json          ← Dependencies
├── src/
│   └── index.js         ← All Cloud Function code
└── node_modules/        ← Installed packages (auto-created)

firebase.json            ← Firebase config (UPDATED)
.firebaserc              ← Project reference (auto-created)
```

---

## Troubleshooting

**Can't see "Upgrade to Blaze" button?**
- Make sure you're logged in: `firebase login`

**npm install failed?**
- Run again: `cd functions && npm install`

**Deployment fails after upgrade?**
- Wait 5 minutes for APIs to be enabled
- Try again: `firebase deploy --only functions`

**Functions not working after deploy?**
- Check logs: `firebase functions:log`
- Verify Firestore collection names match
- Ensure email service credentials are set

---

## What's Next

Once deployed:
1. ✅ Emails send automatically when orders placed
2. ✅ Push notifications send to users in real-time
3. ✅ OTP tokens cleaned up daily
4. ✅ Failed emails retry automatically
5. ✅ Daily reports generated for admins

Your notification system will be **100% COMPLETE**! 🎉

---

## Quick Reference

```powershell
# View logs
firebase functions:log

# View specific function
firebase functions:log --only processEmailQueue

# Redeploy (if you make changes)
firebase deploy --only functions

# Set environment variable
firebase functions:config:set sendgrid.api_key="value"

# Get current config
firebase functions:config:get
```

**See detailed instructions in:** `UPGRADE_TO_BLAZE.md`
