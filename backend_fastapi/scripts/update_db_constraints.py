import os
from supabase import create_client, Client
from dotenv import load_dotenv

load_dotenv()

url = os.environ.get("SUPABASE_URL")
key = os.environ.get("SUPABASE_KEY")
supabase: Client = create_client(url, key)

# This script updates the database constraints to allow new hazard types
# Note: Supabase Python client doesn't directly run raw SQL unless using a specifically exposed function,
# but we can try to use the rpc or just advise the user.
# However, usually we can use `supabase.postgrest.rpc()` if there's an `exec_sql` function.

print("Please run the following SQL in your Supabase SQL Editor to update the constraints:")
print("""
ALTER TABLE public.warnings 
DROP CONSTRAINT IF EXISTS warnings_hazard_type_check;

ALTER TABLE public.warnings 
ADD CONSTRAINT warnings_hazard_type_check 
CHECK (hazard_type IN ('flood', 'landslide', 'typhoon', 'earthquake', 'forecast', 'aid', 'infrastructure'));
""")
