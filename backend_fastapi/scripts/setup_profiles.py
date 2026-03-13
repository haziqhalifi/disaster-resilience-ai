import os
import sys
from supabase import create_client, Client
from dotenv import load_dotenv

# Add parent dir to path so we can import app
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

load_dotenv()

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_KEY")

if not url or not key:
    print("Error: SUPABASE_URL and SUPABASE_KEY must be set in .env")
    sys.exit(1)

supabase: Client = create_client(url, key)

SQL = """
CREATE TABLE IF NOT EXISTS public.user_profiles (
    user_id                        TEXT PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
    full_name                      TEXT,
    phone_number                   TEXT,
    blood_type                     TEXT,
    profile_photo_url              TEXT,
    allergies                      TEXT NOT NULL DEFAULT '',
    medical_conditions             TEXT NOT NULL DEFAULT '',
    emergency_contact_name         TEXT,
    emergency_contact_relationship TEXT,
    emergency_contact_phone        TEXT,
    updated_at                     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;

-- Note: In a real app, you'd use policies to restrict access to the owner.
-- For this prototype, we'll allow service role access.
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'user_profiles' AND policyname = 'Service role full access'
    ) THEN
        CREATE POLICY "Service role full access" ON public.user_profiles
            FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;
"""

print("Please run the following SQL in your Supabase SQL Editor to create the user_profiles table:")
print(SQL)

# We can't easily run raw SQL from the python client without a helper function (rpc)
# But we can try to insert a dummy record to see if it works, but that might fail if table isn't there.
# Best is to advise the user to run the SQL in the dashboard.
