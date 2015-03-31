local uv = require"lluv"
local httpCodec = require"lluver/http-codec"
local url = require"lluver/url"

local exports = {}

local defaultSettings = {
	host = "127.0.0.1", --localhost
	port = 8080,
	maxQueue = 128
}

local lluver = {}

lluver.routes = {
	GET = {}
}

lluver.defaultResponse = {
	code = 200,
	{"Content-Type", "text/plain"}
}

lluver.defaultErrorResponse = {
	code = 404, 
	body = "404 Not Found"
}

function lluver:get(route, callback)
	self.routes.GET[route] = callback
end

function lluver:makeResponse(req, resp)
	local headers = self.defaultResponse
	local body = ""
	if type(resp) == "string" then
		body = resp
	else
		body = resp.body
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

function lluver:onRequest(req)
	local options = url.parse(req.path, true)
	req.pathname = options.pathname
	req.params = options.query

	if type(self.routes[req.method][req.pathname]) == "function" then
		self:makeResponse(req, self.routes[req.method][req.pathname](req))
	else
		self:errorResponse(req)
	end
end

function lluver.unpackHeaders(event)
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
				req = lluver.unpackHeaders(event)
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