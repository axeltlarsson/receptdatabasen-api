-- response body postprocess mode
local NONE = 0
local CHUNKS = 1
local ALL = 2

--- Set the body postprocess mode in the current context.
--- @param mode number The mode to set (NONE, CHUNKS, or ALL).
local function set_body_postprocess_mode(mode)
    ngx.ctx.body_postprocess_mode = mode
end

--- Get the current body postprocess mode.
--- @return number mode The current mode (NONE, CHUNKS, or ALL).
local function get_body_postprocess_mode()
    return ngx.ctx.body_postprocess_mode
end

--- Get the function responsible for postprocessing the response body.
--- @return function|nil fn The postprocess function or nil if not set.
local function get_body_postprocess_fn()
    return ngx.ctx.body_postprocess_fn
end

--- Set the function responsible for postprocessing the response body.
--- @param fn function The postprocess function to set.
local function set_body_postprocess_fn(fn)
    ngx.ctx.body_postprocess_fn = fn
end

--- Buffer the response body during processing.
--- This function collects response body chunks and returns the full response
--- when the end of the stream is reached.
--- @return string|nil resp_body The buffered response body, or nil if not at the end of the stream.
local function buffer_response_body()
    local chunk, eof = ngx.arg[1], ngx.arg[2]
    local buffered = ngx.ctx.buffered_respose_body
    if not buffered then
        buffered = {}
        ngx.ctx.buffered_respose_body = buffered
    end
    if chunk ~= "" then
        buffered[#buffered + 1] = chunk
        ngx.arg[1] = nil
    end
    if eof then
        local response = table.concat(buffered)
        ngx.ctx.buffered_respose_body = nil
        -- ngx.arg[1] = response
        ngx.arg[1] = nil
        return response
    end
end

--- Return an error response with the specified message and HTTP error code.
--- @param msg string The error message to include in the response.
--- @param error_code number|nil The HTTP error code (default is ngx.HTTP_BAD_REQUEST).
local function return_error(msg, error_code)
    ngx.status = error_code or ngx.HTTP_BAD_REQUEST
    ngx.log(ngx.WARN, msg)
    ngx.say(cjson.encode({ error = msg }))
    ngx.exit(ngx.OK)
end

--- Calculate a 12-character truncated HMAC-SHA1 signature.
--- The signature is calculated using the secret key and the size string concatenated with the URL.
--- The signature is then base64-encoded and truncated to 12 characters.
--- @param secret_key string The secret key to use for the signature.
--- @param size string|number The size to include in the signature.
--- @param image_file string The file name of the image to include in the signature.
--- @return string signature The truncated signature.
local function calculate_signature(secret_key, size, image_file)
    return ngx.encode_base64(ngx.hmac_sha1(secret_key, tostring(size) .. image_file))
        :gsub("[+/=]", { ["+"] = "-", ["/"] = "_", ["="] = "," })
        :sub(1, 12)
end

--- Generate a signed image URL using the specified secret key and size.
--- The signature is calculated using calculate_signature.
--- The return url will look like:
--- {scheme}://{host}{port_suffix}/{url_path}/{signature}/{size}/{image_url}
--- e.g. http://localhost:8081/public-images/abc123/700/image.jpg
--- scheme, host and port_suffix are calculated from ngx.var:s
--- @param url_path string The base URL path to use for the signed URL.
--- @param image_file string The file name of the image to sign.
--- @param size string|number The size string to include in the signature.
--- @param secret_key string The secret key to use for the signature.
--- @return string signed_image_url The cryptographically signed image URL.
local function signed_image_url(url_path, image_file, size, secret_key)
    local signature = calculate_signature(secret_key, size, image_file)
    local scheme, host, port = ngx.var.scheme, ngx.var.host, ngx.var.server_port
    local port_suffix = (port ~= "80" and port ~= "443") and ":" .. port or ""
    return scheme ..
        "://" .. host .. port_suffix .. "/" .. url_path .. "/" .. signature .. "/" .. tostring(size) .. "/" .. image_file
end

--- Get the base URL of the site, including protocol, domain and port if applicable.
--- Determines the public-facing base URL by checking reverse proxy headers if available,
--- and if not server variables (for local dev)
--- Can be overridden by setting the SITE_BASE_URL environment variable
--- @return string base_url the public-facing base url e.g. "https://example.com" or "http://localhost:8080"
local function get_base_url()
    -- Override: the SITE_BASE_URL environment variable
    local env_base_url = os.getenv("SITE_BASE_URL")
    if env_base_url and env_base_url ~= "" then
        print("Using SITE_BASE_URL: " .. env_base_url)
        return env_base_url
    end

    -- Check for forwarded headers (from reverse proxy)
    local host = ngx.req.get_headers()["X-Forwarded-Host"]
    local scheme = ngx.req.get_headers()["X-Forwarded-Proto"]
    local port_suffix = ""

    if not (host and scheme) then
        print("Forwarded headers not available, falling back to server variables")
        -- Fall back to server variables if forwarded headers aren't available
        local port = ngx.var.server_port
        port_suffix = (port ~= "80" and port ~= "443") and ":" .. port or ""
        host = ngx.var.host or ngx.var.server_name or "localhost"
        scheme = ngx.var.scheme or "http"
    end

    return scheme .. "://" .. host .. port_suffix
end


return {
    postprocess_modes = {
        NONE = NONE,
        CHUNKS = CHUNKS,
        ALL = ALL,
    },
    set_body_postprocess_mode = set_body_postprocess_mode,
    get_body_postprocess_mode = get_body_postprocess_mode,
    buffer_response_body = buffer_response_body,
    get_body_postprocess_fn = get_body_postprocess_fn,
    set_body_postprocess_fn = set_body_postprocess_fn,
    return_error = return_error,
    calculate_signature = calculate_signature,
    signed_image_url = signed_image_url,
    get_base_url = get_base_url,
}
