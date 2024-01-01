cjson = require('cjson')
utils = require('utils')

hooks = require("hooks")
resty_session = require("resty.session")

if type(hooks.on_init) == 'function' then
		-- initialize session with some options
		if os.getenv("DEVELOPMENT") == "1" then
			-- setting this to false makes it easier to serve dev on non-localhost
			cookie_secure = false
		else
			cookie_secure = true
		end

		print("cookie_secure: ")
		print(cookie_secure)
		print(os.getenv("development"))

		resty_session.init({
				audience = "receptdatabasen",
				remember = true,
				remember_cookie_name = "receptdatabasen_persistent",
				storage = "cookie",
				secret = os.getenv("COOKIE_SESSION_SECRET"),
				cookie_name = "receptdatabasen_session",
				cookie_http_only = true,
				cookie_secure = cookie_secure,
				cookie_same_site = 'Strict',
				-- persistent cookie timeous, I don't care about refresh cookies so those options I disable
				remember_rolling_timeout = tonumber(os.getenv("COOKIE_SESSION_LIFETIME")) or 60480, -- default: a week
				remember_absolute_timeout = 0,
				-- session cookie set to timeout quickly
				idling_timeout = 10,
				rolling_timeout = 0,
				absolute_timeout = 0,
			})
		hooks.on_init()
end

