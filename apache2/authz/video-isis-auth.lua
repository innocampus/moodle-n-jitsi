-- Author Henryk Iwaniuk
-- Mail: iwaniuk@math.tu-berlin.de
-- Date: 22.09.2018
-- update for jitsi by Marc-Robin Wendt
-- wendt@math.tu-berlin.de
-- 29.02.2020

require 'apache2'
require 'os'
local https = require 'ssl.https'

local token = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

-- loglevel (2=debug,1=notice,0=none)
local loglevel = 2

local function starts_with(str, start)
   return str:sub(1, #start) == start
end

function ISIS_ACL_handler(r, access_mode)

	local function write_to_log(mode,str)
		if loglevel >= mode then
 			if mode == 1 then
				r:notice(str)
			end
 			if mode == 2 then
				r:debug(str)
			end
		end
	end


        if r.user == nil then
                -- falls der authz vor der authentication aufgerufen wird.
                -- dieser rueckgabewert sorgt dafuer, dass der handler nach der
                -- authentication erneut von apache aufgerufen wird.
                return apache2.AUTHZ_DENIED_NO_USER
        end

	local uri = r.unparsed_uri
	local user = r.user


	local isis_id=""
	if string.match(uri, "http%-bind%?room=") then
		for word in string.gmatch(uri, "isis0?(.+)") do isis_id=word end

		local id_is_valid = isis_id:match('^([0-9]+)$')

		if not id_is_valid then
			write_to_log(2, "passing, no isis id " .. user .. " - " .. uri .. " ")
			r.status=404
			return apache2.AUTHZ_DENIED
		else
			isis_id = string.format("%u", isis_id)
			write_to_log(2, "isis_id is " .. isis_id)
		end
	else
                write_to_log(2, "passing, no room uri " .. user .. " - " .. uri)
                return apache2.AUTHZ_GRANTED
	end

	local url = "https://moodle.tu-berlin.de/webservice/rest/server.php?wstoken=" .. token .. "&wsfunction=local_isis_video_check_access&moodlewsrestformat=json&courseid=" .. isis_id .. "&username=" .. user .. "&type=" .. access_mode

	local body, code, headers, status = https.request(url)
	write_to_log(1, "[" .. status .. "] user: " .. r.user .. " " .. isis_id)

        if starts_with(body, "true") then
                write_to_log(1, " Passed!")
		return apache2.AUTHZ_GRANTED
        else
                write_to_log(1, " Blocked! Body: " .. body)
		r.status=404
                return apache2.AUTHZ_DENIED
        end

	r.status=404
        return apache2.AUTHZ_DENIED
end

