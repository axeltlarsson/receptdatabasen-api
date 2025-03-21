drop schema if exists utils cascade;
create schema utils;

-- Make sure pgcrypto extension is installed
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Function to calculate image signature
CREATE OR REPLACE FUNCTION utils.calculate_image_signature(
    size text,
    url text
) RETURNS text AS $$
DECLARE
    secret_key text;
    combined_text text;
    hmac_result bytea;
    base64_result text;
    url_safe_result text;
BEGIN
    secret_key := settings.get('image_server_secret');
    
    -- Combine size and URL (equivalent to Lua's tostring(size) .. url)
    combined_text := size || url;
    
    -- Calculate HMAC-SHA1 (equivalent to ngx.hmac_sha1)
    hmac_result := public.hmac(combined_text, secret_key, 'sha1');
    
    -- Encode as base64 (equivalent to ngx.encode_base64)
    base64_result := encode(hmac_result, 'base64');
    
    -- Replace characters to make URL-safe (equivalent to gsub in Lua)
    -- Replace '+' with '-', '/' with '_', and '=' with ','
    url_safe_result := translate(base64_result, '+/=', '-_,');
    
    -- Take first 12 characters (equivalent to :sub(1, 12) in Lua)
    RETURN substring(url_safe_result, 1, 12);
END;
$$ LANGUAGE plpgsql STABLE security definer;-- set search_path = utils, public, pg_temp;

-- Function to generate a signed URL for an image
CREATE OR REPLACE FUNCTION utils.generate_signed_image_url(
    url_path text,
    image_path text,
    size integer DEFAULT 600
) RETURNS text AS $$
DECLARE
    signature text;
BEGIN
    -- Calculate signature
    signature := utils.calculate_image_signature(size::text, image_path);
    
    -- Return the full signed URL
    RETURN url_path || '/' || signature || '/' || size || '/' || image_path;
END;
$$ LANGUAGE plpgsql STABLE security definer set search_path = utils, pg_temp;

