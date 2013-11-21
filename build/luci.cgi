#!/usr/bin/lua5.1

dofile "../../build/setup.lua"

require "luci.cacheloader"
require "luci.sgi.cgi"
luci.dispatcher.indexcache = "/tmp/luci-indexcache"
luci.sgi.cgi.run()
