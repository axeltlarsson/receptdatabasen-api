-- Instagram Image Downloader Module
-- Downloads images from Instagram and saves them locally

local http = require "resty.http"
local mime_sniff = require "lib.mime_sniff"

local M = {}

local mime_type_map = {
    ["image/bmp"] = ".bmp",
    ["image/gif"] = ".gif",
    ["image/jpeg"] = ".jpeg",
    ["image/png"] = ".png",
    ["image/webp"] = ".webp"
}

local supported_mime_types = {}
for key, _ in pairs(mime_type_map) do
    table.insert(supported_mime_types, key)
end

-- Generate unique filename
local function generate_filename()
    local r = ngx.now() + math.random()
    return ngx.md5(tostring(r))
end

-- Get file extension for mime type
local function file_ext(mime_type)
    return mime_type_map[mime_type]
end

--- Download an image from URL and save it locally
--- @param image_url string The URL of the image to download
--- @return table|nil result Contains url (jpeg) and originalUrl
--- @return string|nil error Error message if failed
function M.download_and_save(image_url)
    if not image_url or image_url == "" then
        return nil, "No image URL provided"
    end

    -- Get upload path from environment
    local upload_path = os.getenv("FILE_UPLOAD_PATH")
    if not upload_path then
        return nil, "FILE_UPLOAD_PATH environment variable is not set"
    end

    -- Fetch the image
    local httpc = http.new()
    httpc:set_timeout(30000)  -- 30 second timeout for images

    local res, err = httpc:request_uri(image_url, {
        method = "GET",
        headers = {
            ["User-Agent"] = "Mozilla/5.0 (compatible; RecipeBot/1.0)",
        },
        ssl_verify = false,
    })

    if not res then
        return nil, "Failed to fetch image: " .. (err or "unknown error")
    end

    if res.status ~= 200 then
        return nil, "Image fetch returned status " .. res.status
    end

    local body_data = res.body
    if not body_data or #body_data == 0 then
        return nil, "Empty image response"
    end

    -- Sniff MIME type
    local mime_type = mime_sniff.match_content_type(body_data, table.unpack(supported_mime_types))
    if not mime_type then
        return nil, "Unsupported image format"
    end

    -- Generate filename and save
    local name = generate_filename()
    local file_path = upload_path .. "/" .. name

    -- Save original
    local ext = file_ext(mime_type)
    local file, file_err = io.open(file_path .. ext, 'w+b')
    if not file then
        return nil, "Failed to create file: " .. (file_err or "unknown error")
    end

    local ok, write_err = file:write(body_data)
    file:close()

    if not ok then
        return nil, "Failed to write file: " .. (write_err or "unknown error")
    end

    -- Convert to JPEG using vips
    local vips = require "vips"
    local convert_ok, convert_err = pcall(function()
        local image = vips.Image.new_from_buffer(body_data)
        image:jpegsave(file_path .. ".jpeg")
    end)

    if not convert_ok then
        ngx.log(ngx.WARN, "Failed to convert image to JPEG: " .. (convert_err or "unknown"))
        -- Still return the original if conversion fails
        return {
            url = name .. ext,
            originalUrl = name .. ext,
        }
    end

    return {
        url = name .. ".jpeg",
        originalUrl = name .. ext,
    }
end

return M
