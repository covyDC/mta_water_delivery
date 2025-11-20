# Cloud Functions Deployment - Blaze Plan Upgrade Required

## Status: Ready to Deploy ✓

Your Cloud Functions code is **100% ready to deploy**. All files have been created and installed locally.

## What You Need to Do

Firebase Cloud Functions require a **Blaze (pay-as-you-go)** billing plan. The Spark (free) plan does not support Cloud Functions.

### Step 1: Upgrade to Blaze Plan

1. Open the Firebase Console upgrade page:
   ```
   https://console.firebase.google.com/project/mta-water-delivery-8697f/usage/details
   ```

2. Click **"Upgrade to Blaze"** button

3. Follow the prompts to add your payment method

4. Once upgraded, you'll see: "Blaze plan enabled"

### Step 2: Set Up Email Service (Choose One)

#### Option A: SendGrid (Recommended - Free tier available)

1. Go to https://sendgrid.com
2. Sign up (free account allows 100 emails/day)
3. Go to Settings → API Keys
4. Create a new API key
5. Copy the key and run:
   ```powershell
   cd C:\COVY\mta_water_delivery
   firebase functions:config:set sendgrid.api_key="sk-your-key-here"
   ```

#### Option B: Gmail (Simple but less reliable)

1. Enable 2-Factor Authentication on your Google account
2. Go to https://myaccount.google.com/apppasswords
3. Select "Mail" and "Windows Computer"
4. Generate an app password
5. Run:
   ```powershell
   firebase functions:config:set gmail.email="your-email@gmail.com"
   firebase functions:config:set gmail.password="your-app-password"
   ```

### Step 3: Deploy Cloud Functions

Once your project is upgraded to Blaze, run:

```powershell
cd C:\COVY\mta_water_delivery
firebase deploy --only functions
```

This will deploy 5 Cloud Functions:
- ✓ **processEmailQueue** - Sends queued emails automatically
- ✓ **cleanupExpiredOTPs** - Removes expired OTP tokens daily
- ✓ **retryFailedEmails** - Retries failed emails daily
- ✓ **sendPushNotification** - Sends push notifications via FCM
- ✓ **generateDailyReports** - Generates and emails daily reports

## Cost Breakdown

**Free tier includes:**
- 2,000,000 invocations per month
- 400,000 GB-seconds of compute

**For a typical water delivery app:**
- ~100 orders/day = 3,000 function invocations/month
- Estimated monthly cost: **$0-$1** (usually free tier)

You only pay if you exceed free tier limits.

## What Happens After Deployment

### Email Notifications
- When a customer places an order → Email sent automatically
- When delivery status changes → Email sent automatically
- Failed emails retry automatically (up to 3 times)

### Push Notifications
- When notification document created → Push sent to user's device
- Requires FCM token to be saved in user's profile

### Automated Tasks
- **Daily at 2 AM**: Removes expired OTP tokens (2FA cleanup)
- **Daily at 2:30 AM**: Retries any failed emails
- **Daily at 6 PM**: Generates daily report and emails to all admins

## Files Already Created

✓ `/functions/package.json` - Project dependencies
✓ `/functions/src/index.js` - All Cloud Function code
✓ `/functions/.gitignore` - Git ignore rules
✓ `firebase.json` - Firebase configuration (updated)
✓ `/functions/node_modules/` - Dependencies installed

## Verification

After deployment completes, verify in Firebase Console:

1. Go to: https://console.firebase.google.com/project/mta-water-delivery-8697f/functions/list
2. You should see 5 functions listed
3. Click each to view logs and verify they're running

## Commands After Upgrade

```powershell
# View Cloud Functions logs
firebase functions:log

# Redeploy if you make changes
firebase deploy --only functions

# View specific function logs
firebase functions:log --only processEmailQueue

# Test a function (if needed)
firebase functions:shell
```

## Troubleshooting

**Error: "Blaze plan required"**
- You haven't upgraded yet. Go to the Firebase Console upgrade link above.

**Error: "SENDGRID_API_KEY not set"**
- Run: `firebase functions:config:set sendgrid.api_key="your-key"`

**Error: "Cloud Build API not enabled"**
- This automatically enables during deployment (takes a few minutes)

**Function not triggering**
- Check Firebase Console → Functions → Logs
- Verify Firestore collection names match (emailQueue, notifications, etc.)

## Next Steps

1. ✅ Upgrade to Blaze plan
2. ✅ Configure email service (SendGrid or Gmail)
3. ✅ Run `firebase deploy --only functions`
4. ✅ Verify deployment in Firebase Console
5. ✅ Test by creating a test email in `emailQueue` collection

Once deployed, your notification system will be **100% operational**!

---

**Need help?** Check Firebase documentation:
- Cloud Functions: https://firebase.google.com/docs/functions
- Billing: https://firebase.google.com/docs/projects/billing
