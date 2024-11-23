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
--- @return number The current mode (NONE, CHUNKS, or ALL).
local function get_body_postprocess_mode()
  return ngx.ctx.body_postprocess_mode
end

--- Get the function responsible for postprocessing the response body.
--- @return function|nil The postprocess function or nil if not set.
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
--- @return string|nil The buffered response body, or nil if not at the end of the stream.
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
}
