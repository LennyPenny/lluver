local luv = require"luv"
local httpCodec = require"luaWebs/http-codec"
local url = require"luaWebs/url"

local exports = {}

local defaultSettings = {
	host = "127.0.0.1", --localhost
	port = 8080,
	maxQueue = 128
}

local luaWebs = {}

luaWebs.routes = {
	GET = {},
	POST = {}
}

luaWebs.defaultResponse = {
	code = 200,
	{"Content-Type", "text/plain"}
}

function luaWebs:get(route, callback)
	self.routes.GET[route] = callback
end

function luaWebs:onRequest(req)
	local options = url.parse(req.path, true)
	req.pathname = options.pathname
	req.params = options.query

	local function makeResponse(resp)
		local headers = luaWebs.defaultResponse
		local body = ""
		if type(resp) == "string" then
			body = resp
		else
			for k, v in pairs(resp) do
				header[k] = v
			end
		end
		local encoder = httpCodec.encoder()
		luv.write(req.clientHandle, encoder(headers))
		luv.write(req.clientHandle, encoder(body))
		luv.close(req.clientHandle)
	end
	
	if type(self.routes[req.method][req.pathname]) == "function" then
		makeResponse(self.routes[req.method][req.pathname](req))
	end
end

function luaWebs.unpackHeaders(event)
	event.headers = {}
	for k, v in ipairs(event) do
		local name, value = table.unpack(v)
		event.headers[name] = value
		event[k] = nil
	end
	return event
end

function luaWebs:onConnection(clientHandle)
	local decoder = httpCodec.decoder()

	local buffer = ""
	local req = {}
	local function onChunk(chunk)
		while true do
			buffer = buffer..chunk
			local event, extra = decoder(buffer)

			if not extra then break end
			buffer = extra
			if type(event) == "table" then
				req = luaWebs.unpackHeaders(event)
			elseif type(event) == "string" then
				if #event == 0 then 
					req.clientHandle = clientHandle
					self:onRequest(req)
					break
				else
					req.body = event
				end
			end
		end
	end
	local function onRead(err, chunk)
		if err then
			luv.close(clientHandle)
			return 
		end
		if chunk then
			onChunk(chunk)
		else
			luv.close(clientHandle)
		end
	end
	luv.read_start(clientHandle, onRead)
end

function luaWebs:start()
	print"starting tcp socket..."
	self.handle = luv.new_tcp()
	luv.tcp_bind(self.handle, self.host, self.port)

	local function onCallback()
		local clientHandle = luv.new_tcp()
		luv.accept(self.handle, clientHandle)
		self:onConnection(clientHandle)
	end
	luv.listen(self.handle, self.maxQueue, onCallback)
end

function luaWebs:stop()
	print"stopping..."
	luv.close(self.handle)
end

function luaWebs:setSettings(settings)
	for setting, v in pairs(settings) do
		self[setting] = v
	end
end

local luaWebsMeta = {__index = luaWebs} --make all instances be created from the same metatable


function exports.create(settings)
	local self = setmetatable({}, luaWebsMeta)

	self:setSettings(defaultSettings)

	if settings then self:setSettings(settings) end

	return self
end

function exports.setDefaultSettings(settings)
	for setting, v in pairs(setting) do
		defaultSettings[setting] = v
	end
end

exports.run = luv.run --so you dont have to require luv when changing the event loop
exports.stop = luv.stop


return exports