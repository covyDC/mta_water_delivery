# Cloud Functions Environment Setup

## Step 1: Get Your API Key

### Option 1: SendGrid (Recommended)
1. Go to https://sendgrid.com (create free account if needed)
2. Navigate to Settings → API Keys
3. Create a new API key and copy it

### Option 2: Gmail
1. Enable 2FA on your Google account
2. Go to https://myaccount.google.com/apppasswords
3. Select Mail and Windows Computer
4. Generate an app password

## Step 2: Set Environment Variables

### For SendGrid:
```powershell
cd C:\COVY\mta_water_delivery
firebase functions:config:set sendgrid.api_key="sk-..."
```

### For Gmail:
```powershell
firebase functions:config:set gmail.email="your-email@gmail.com"
firebase functions:config:set gmail.password="your-app-password"
```

## Step 3: Verify Configuration
```powershell
firebase functions:config:get
```

## Step 4: Deploy
```powershell
firebase deploy --only functions
```

## Troubleshooting

If you see "not logged in" error:
```powershell
firebase login
```

If deployment fails, check the logs:
```powershell
firebase functions:log
```
