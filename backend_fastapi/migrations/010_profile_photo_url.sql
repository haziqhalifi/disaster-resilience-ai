-- Add profile photo URL field to user profiles.
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS profile_photo_url TEXT;
