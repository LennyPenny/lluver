# lluver

A lua api-server designed to get out of your way. 

#Example

```lua
local lluver = require"lluver"

local server = lluver.create() --binds to port 8080 by default
server:get("/:name/hello", function(req) --easily parameterize your urls
	return "Hey "..req.urlParams.name.."!" --if you just want to return json or something, put it here!
end)

server:start() --make it get ready (you can start more than one server before calling run)

lluver.run() --start the event loop

```
