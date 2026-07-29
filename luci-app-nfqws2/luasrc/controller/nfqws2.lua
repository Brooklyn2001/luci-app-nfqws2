module("luci.controller.nfqws2", package.seeall)

function index()
	entry({"admin", "services", "nfqws2"}, alias("admin", "services", "nfqws2", "config"),
		_("NFQWS2"), 10).dependent = true

	entry({"admin", "services", "nfqws2", "config"},
		cbi("nfqws2/config"), _("Configuration"), 10).leaf = true

	entry({"admin", "services", "nfqws2", "lists"},
		cbi("nfqws2/lists"), _("Domain Lists"), 20).leaf = true

	entry({"admin", "services", "nfqws2", "logs"},
		cbi("nfqws2/logs"), _("Logs"), 30).leaf = true

	entry({"admin", "services", "nfqws2", "scripts"},
		cbi("nfqws2/scripts"), _("Lua Scripts"), 40).leaf = true

	-- RPC calls
	entry({"admin", "services", "nfqws2", "status"}, call("action_status")).leaf = true
	entry({"admin", "services", "nfqws2", "action"}, call("action_service")).leaf = true
	entry({"admin", "services", "nfqws2", "filenames"}, call("action_filenames")).leaf = true
	entry({"admin", "services", "nfqws2", "filecontent"}, call("action_filecontent")).leaf = true
	entry({"admin", "services", "nfqws2", "savefile"}, call("action_savefile")).leaf = true
	entry({"admin", "services", "nfqws2", "createfile"}, call("action_createfile")).leaf = true
	entry({"admin", "services", "nfqws2", "removefile"}, call("action_removefile")).leaf = true
	entry({"admin", "services", "nfqws2", "checkdomain"}, call("action_checkdomain")).leaf = true
	entry({"admin", "services", "nfqws2", "upgrade"}, call("action_upgrade")).leaf = true
end

local function json_response(data)
	luci.http.prepare_content("application/json")
	luci.http.write_json(data)
end

function action_status()
	local fs = require "luci.fs"
	local ret = {
		running = false,
		nfqws2  = fs.access("/usr/bin/nfqws2"),
	}

	local f = io.popen("pidof nfqws2 2>/dev/null")
	if f then
		ret.running = (#f:read("*a"):trim() > 0)
		f:close()
	end

	f = io.popen([[opkg status nfqws2-keenetic 2>/dev/null | awk -F': ' '/^Version:/ {print $2}']])
	if f then
		ret.version = f:read("*a"):trim()
		f:close()
	end

	json_response(ret)
end

function action_service()
	local action = luci.http.formvalue("action")
	if not action then
		json_response({status = 1, output = {"No action specified"}})
		return
	end

	local script = "/etc/init.d/nfqws2"

	local cmd = string.format("%s %s 2>&1", script, action)
	local output = {}
	local f = io.popen(cmd)
	if f then
		for line in f:lines() do
			table.insert(output, line)
		end
		f:close()
	end
	if #output == 0 then
		table.insert(output, string.format("Executed: %s", cmd))
	end

	json_response({status = 0, output = output})
end

function action_filenames()
	local ftype = luci.http.formvalue("type")
	local paths = {
		conf = "/etc/nfqws2",
		list = "/etc/nfqws2/lists",
		log  = "/var/log",
		lua  = "/etc/nfqws2/lua",
	}

	local base_dir = paths[ftype] or paths.conf
	local files = {}
	if luci.fs.access(base_dir) then
		for f in io.popen(string.format('ls -1 "%s" 2>/dev/null', base_dir)):lines() do
			local ext = f:match("%.(%w+)$")
			if not ext then
				ext = f:match("%.(%w+)%.gz$")
			end

			local ok = false
			if ftype == "conf" and (ext == "conf" or ext == "conf-opkg" or ext == "conf-old") then ok = true end
			if ftype == "list" and (ext == "list" or ext == "list-opkg" or ext == "list-old") then ok = true end
			if ftype == "lua"  and ext == "lua" then ok = true end
			if ftype == "log"  and ext == "log" and f:match("^nfqws") then ok = true end

			if ok then
				table.insert(files, f:gsub("%.gz$", ""))
			end
		end
	end

	table.sort(files)
	json_response({status = 0, files = files})
end

function action_filecontent()
	local filename = luci.http.formvalue("filename")
	if not filename then
		json_response({status = 1, content = ""})
		return
	end

	local base = filename:gsub("%.gz$", "")
	local path

	if base:match("%.list$") then
		path = "/etc/nfqws2/lists/" .. base
	elseif base:match("%.log$") then
		path = "/var/log/" .. base
	elseif base:match("%.lua$") then
		path = "/etc/nfqws2/lua/" .. base
	else
		path = "/etc/nfqws2/" .. base
	end

	local content = ""
	local f = io.open(path, "r")
	if f then
		content = f:read("*a")
		f:close()
	end

	-- Reverse log lines
	if base:match("%.log$") then
		local lines = {}
		for line in content:gmatch("[^\r\n]+") do
			table.insert(lines, line)
		end
		local reversed = {}
		for i = #lines, 1, -1 do
			table.insert(reversed, lines[i])
		end
		content = table.concat(reversed, "\n")
	end

	json_response({status = 0, content = content, filename = filename})
end

function action_savefile()
	local filename = luci.http.formvalue("filename")
	local content  = luci.http.formvalue("content")

	if not filename or not content then
		json_response({status = 1, filename = filename})
		return
	end

	local base = filename:gsub("%.gz$", "")
	local path

	if base:match("%.list$") then
		path = "/etc/nfqws2/lists/" .. base
	elseif base:match("%.log$") then
		json_response({status = 1, filename = filename})
		return
	elseif base:match("%.lua$") then
		path = "/etc/nfqws2/lua/" .. base
	else
		path = "/etc/nfqws2/" .. base
	end

	content = content:gsub("\r\n", "\n"):gsub("\r", "\n")
	content = content:gsub("\n\n\n+", "\n\n")
	if #content > 0 and content:sub(-1) ~= "\n" then
		content = content .. "\n"
	end

	local f = io.open(path, "w")
	if f then
		f:write(content)
		f:close()
		json_response({status = 0, filename = filename})
	else
		json_response({status = 1, filename = filename})
	end
end

function action_createfile()
	local filename = luci.http.formvalue("filename")
	if not filename or not filename:match("^[a-zA-Z0-9_%-]+%.(list|lua|conf)$") then
		json_response({status = 1, filename = filename})
		return
	end

	local path
	if filename:match("%.list$") then
		path = "/etc/nfqws2/lists/" .. filename
	elseif filename:match("%.lua$") then
		path = "/etc/nfqws2/lua/" .. filename
	else
		path = "/etc/nfqws2/" .. filename
	end

	if luci.fs.access(path) then
		json_response({status = 1, filename = filename})
		return
	end

	local f = io.open(path, "w")
	if f then
		f:close()
		json_response({status = 0, filename = filename})
	else
		json_response({status = 1, filename = filename})
	end
end

function action_removefile()
	local filename = luci.http.formvalue("filename")
	if not filename then
		json_response({status = 1, filename = ""})
		return
	end

	local base = filename:gsub("%.gz$", "")
	local path

	if base:match("%.list$") then
		path = "/etc/nfqws2/lists/" .. base
	elseif base:match("%.lua$") then
		path = "/etc/nfqws2/lua/" .. base
	else
		path = "/etc/nfqws2/" .. base
	end

	if luci.fs.access(path) then
		luci.fs.remove(path)
		json_response({status = 0, filename = filename})
	else
		json_response({status = 1, filename = filename})
	end
end

function action_checkdomain()
	local url = luci.http.formvalue("url")
	if not url then
		json_response({status = 1, result = false})
		return
	end

	if not luci.fs.access("/usr/bin/curl") then
		json_response({status = 0, result = false, note = "curl not installed"})
		return
	end

	local f = io.popen(string.format(
		'curl -sIL --max-time 5 --max-redirs 5 "%s" 2>/dev/null | head -1', url))
	local result = false
	if f then
		local line = f:read("*l")
		f:close()
		result = (line and line:match("^HTTP/%d+%.%d+ %d+") ~= nil)
	end

	json_response({status = 0, result = result})
end

function action_upgrade()
	local output = {}
	local f = io.popen("opkg update 2>&1 && opkg upgrade nfqws2-keenetic 2>&1")
	if f then
		for line in f:lines() do
			table.insert(output, line)
		end
		f:close()
	end
	if #output == 0 then
		table.insert(output, "Nothing to update")
	end

	json_response({status = 0, output = output})
end
