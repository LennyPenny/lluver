--[[

Copyright 2015 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

--]]

--taken from https://github.com/luvit/luvit/blob/master/deps/http-codec.lua and modified to run as normal lua module

local exports = {}

exports.name = "luvit/url"
exports.version = "1.0.0"

local querystring = require('luawebs/querystring')

function exports.parse(url, parseQueryString)
  local href = url
  local chunk, protocol = url:match("^(([a-z0-9+]+)://)")
  url = url:sub((chunk and #chunk or 0) + 1)
  local host = url:match("^([^/]+)")
  local hostname, port
  if host then
    hostname = host:match("^([^:/]+)")
    port = host:match(":(%d+)$")
    host = hostname
  end

  url = url:sub((host and #host or 0) + 1)
  local path
  local pathname
  local search
  local query

  if url ~= '' then
    path = url
    local temp
    temp = url:match("^[^?]*")
    if temp ~= '' then
      pathname = temp
    end
    temp = url:sub((pathname and #pathname or 0) + 1)
    if temp ~= '' then
      search = temp
    end
    if search then
    temp = search:sub(2)
      if temp ~= '' then
        query = temp
      end
    end
  end

  if parseQueryString then
    query = querystring.parse(query)
  end

  return {
    href = href,
    protocol = protocol,
    host = host,
    hostname = hostname,
    port = port,
    path = path,
    pathname = pathname,
    search = search,
    query = query
  }

end

return exports