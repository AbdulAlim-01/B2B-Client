# B2B Lead Generator - Flutter & Supabase

A powerful B2B lead generation application built with Flutter and Supabase, leveraging AI to find potential customers based on business descriptions.

## 📺 Project Demo
[![Watch the video](https://api.crazzy.dev/upload/images/b2bclient.png)](https://api.crazzy.dev/upload/images/RDT_20260420_065455.mp4)

## 🚀 Features
- **AI-Powered Keyword Generation**: Uses Google Gemini to analyze business descriptions and generate effective search phrases.
- **Local Business Search**: Integrates with SerpApi (Google Local Search) to find potential leads.
- **Lead Management**: Store and manage leads directly in Supabase.
- **WhatsApp Integration**: Contact potential leads instantly via WhatsApp.
- **Business Profiles**: Customizable business profiles for tailored lead generation.
- **Subscription System**: Built-in lead credit system and payment tracking.

## 🛠️ Tech Stack
- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (Auth, Database, Edge Functions)
- **AI**: Google Gemini Pro (via Edge Functions)
- **Data Source**: SerpApi (Google Local Results)

## 📋 Prerequisites
- Flutter SDK installed
- Supabase account
- Google AI (Gemini) API Key
- SerpApi Key

## ⚙️ Setup Instructions

### 1. Supabase Project Setup
1. Create a new project on [Supabase](https://supabase.com/).
2. Run the following SQL in the SQL Editor to set up the database tables:

```sql
-- Create Business Profiles table
CREATE TABLE business_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  business_name TEXT,
  description TEXT,
  ai_message TEXT,
  keywords JSONB,
  leads_remaining INTEGER DEFAULT 0,
  type TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create Leads table
CREATE TABLE leads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_id UUID REFERENCES business_profiles(id) ON DELETE CASCADE,
  name TEXT,
  phone TEXT,
  address TEXT,
  source_keyword TEXT,
  raw JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create Payments table
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  amount DECIMAL,
  currency TEXT DEFAULT 'INR',
  plan TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 2. Deploy Edge Function
1. Install [Supabase CLI](https://supabase.com/docs/guides/cli).
2. Initialize Supabase in your project: `supabase init`.
3. Create a new function: `supabase functions new hyper-api`.
4. Copy the content from `supabase.txt` (located in the root directory) into `supabase/functions/hyper-api/index.ts`.
5. Set your API keys in the Edge Function:
   - Replace `SERP_API_KEY` with your SerpApi key.
   - Replace `GEMINI_API_KEY` with your Google Gemini API key.
6. Deploy the function: `supabase functions deploy hyper-api`.

### 3. Flutter Configuration
1. Open `lib/main.dart` and add your Supabase URL and Anon Key:
```dart
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);
```
2. Open `lib/services/service.dart` and update the configuration variables:
```dart
const String supabase_url = "YOUR_SUPABASE_PROJECT_ID";
const String supabase_anonkey = "YOUR_SUPABASE_ANON_KEY";
```

### 4. Running the App
```bash
flutter pub get
flutter run
```

## 🔐 Security Note
All API keys and credentials have been removed from this repository for security. Ensure you use your own credentials when setting up the project. Never commit your `.env` files or hardcoded keys to version control.

## 📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
