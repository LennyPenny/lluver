local uv = require"lluv"
local httpCodec = require"lluver/http-codec"
local url = require"lluver/url"

local exports = {}

local defaultSettings = {
	host = "127.0.0.1", --localhost
	port = 8080
}

local lluver = {}

lluver.routes = {}

lluver.defaultResponse = {
	code = 200,
	{"Content-Type", "text/plain"}
}

lluver.defaultErrorResponse = {
	code = 404, 
	body = "404 Not Found"
}

lluver.routeParamSymbol = ":" --used by angular and lapis

function lluver:addRoute(method, route, callback)
	if not lluver.routes[method] then
		lluver.routes[method] = {}
	end

	if not string.find(route, self.routeParamSymbol) then
		lluver.routes[method][route] = callback --super fast access for static routes
		return
	end

	local curpos = lluver.routes[method] --current pos in the route, this only works because lua doesn't do deep copies
	for part in string.gmatch(route, "[^/]+/-") do
		if string.sub(part, 1, #self.routeParamSymbol) == self.routeParamSymbol then
			curpos[1] = {[self.routeParamSymbol] = string.sub(part, #self.routeParamSymbol + 1)} --this is so we know when to set a route param and its name
			curpos = curpos[1]
		else
			curpos[part] = curpos[part] or {}
			curpos = curpos[part]
		end
	end
	curpos.callback = callback
end

function lluver:get(route, callback)
	self:addRoute("GET", route, callback)
end

function lluver:post(route, callback)
	self:addRoute("POST", route, callback)
end

function lluver:put(route, callback)
	self:addRoute("PUT", route, callback)
end

function lluver:delete(route, callback)
	self:addRoute("DELETE", route, callback)
end

function lluver:makeResponse(req, resp)
	local headers = self.defaultResponse
	local body = ""
	if type(resp) == "string" then
		body = resp
	elseif type(resp) == "table" then
		if resp.body then 
			body = resp.body
			resp.body = nil
		end
		for k, v in pairs(resp) do
			headers[k] = v
		end
	end
	local encoder = httpCodec.encoder()
	req.client:write(encoder(headers))
	req.client:write(encoder(body) or "", function(client) client:close() end)
end

function lluver:errorResponse(req)
	self:makeResponse(req, self.defaultErrorResponse)
end

function lluver:callRequestCallback(req)
	if not self.routes[req.method] then
		self:errorResponse(req)
	elseif type(self.routes[req.method][req.pathname]) == "function" then
		self:makeResponse(req, self.routes[req.method][req.pathname](req))
	else
		req.urlParams = {}
		local curpos = self.routes[req.method]
		for part in string.gmatch(req.pathname, "[^/]+/-") do
			if not curpos[part] then
				if curpos[1] then
					req.urlParams[curpos[1][self.routeParamSymbol]] = part
					curpos = curpos[1]
					goto continue
				else
					self:errorResponse(req)
				end
			end
			curpos = curpos[part]
			::continue::
		end
		self:makeResponse(req, curpos.callback(req))
	end
end

function lluver:onRequest(req)
	local options = url.parse(req.path, true)
	req.pathname = options.pathname
	req.params = options.query

	lluver:callRequestCallback(req)
end

function lluver:unpackHeaders(event)
	event.headers = {}
	for k, v in ipairs(event) do
		local name, value = table.unpack(v)
		event.headers[name] = value
		event[k] = nil
	end
	return event
end

function lluver:onConnection(err)
	if err then self.sock:close() error("Failed on connection: ", err) end

	local decoder = httpCodec.decoder()
	local client
	local buffer = ""
	local req = {}

	local function onChunk(chunk)
		while true do
			buffer = buffer..chunk
			local event, extra = decoder(buffer)

			if not extra then break end
			buffer = extra
			if type(event) == "table" then
				req = self:unpackHeaders(event)
			elseif type(event) == "string" then
				if #event == 0 then 
					req.client = client
					self:onRequest(req)
					break
				else
					req.body = event
				end
			end
		end
	end

	local function onRead(clienth, err, chunk)
		if not client then client = clienth end

		if err then
			client:close()
			return
		end

		if chunk then
			onChunk(chunk)
		else
			client:close()
		end
	end
	self.sock:accept():start_read(onRead)
end

function lluver:onBind(err, host, port)
	if err then
		self.sock:close()
		error("Couldn't bind tcp socket: ", err)
	end

	self.host = host..":"..port
	print("Listening on "..self.host)

	local function onConnection(server, err)
		self:onConnection(err)
	end
	self.sock:listen(onConnection)
end

function lluver:start()
	print"starting tcp socket..."
	self.sock = uv.tcp()

	local function onBind(sock, err, host, port)
		self:onBind(err, host, port)
	end
	self.sock:bind(self.host, self.port, onBind)
end

function lluver:stop()
	print"stopping..."
	self.sock:close()
end

function lluver:setSettings(settings)
	for setting, v in pairs(settings) do
		self[setting] = v
	end
end

local lluverMeta = {__index = lluver} --make all instances be created from the same metatable


function exports.create(settings)
	local self = setmetatable({}, lluverMeta)

	self:setSettings(defaultSettings)

	if settings then self:setSettings(settings) end

	return self
end

function exports.setDefaultSettings(settings)
	for setting, v in pairs(setting) do
		defaultSettings[setting] = v
	end
end

exports.run = uv.run --so you dont have to require uv when changing the event loop
exports.stop = uv.stop

return exports