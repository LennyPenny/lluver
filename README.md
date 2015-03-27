# luaWebs

It's a very simple http api-server that's designed to get out of your way.

#Example

```
local luaWebs = require"luaWebs"

local server = luaWebs.create() --binds to port 8080 by default
server:get("/hello/world", function(req)
	return "Hello world!:^D" --if you just want to return json or something, put it here!
end)

server:start() --make it get read (you can start more than one server at once)

luaWebs.run() --start the event loop

```
