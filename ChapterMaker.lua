script_name = "Chapter Genrator"
script_namespace = "ChapterGen.lua"
script_description = "Generates chapter files from lines timeline."
script_version = '1.0.0'
script_author = "Bilal Bassam, Bilal2453@github.com"

local function newChapter(startTime, endTime, cpString, lang, flag)
	if type(startTime) == 'table' then
		endTime 	= startTime.endTime
		cpString	= startTime.cpString
		lang		= startTime.lang
		flag		= startTime.flag
		startTime= startTime.startTime
	end

	return {
		startTime= startTime,
		endTime	= endTime,
		cpString	= cpString,
		lang		= lang,
		flag		= flag and true,
	}
end

---------  ---------

local function hTime(time)
	if not time then return '' end
	local hours, mins, secs, ms

	hours = math.floor((time / 1000) / 3600)
	mins	= math.floor((time / 1000 % 3600) / 60)
	secs	= math.floor((time / 1000) % 60)
	ms		= math.floor((time % 1000))

	return ('%02i:%02i:%02i.%03i'):format(hours, mins, secs, ms)
end

local function OGMAssembler(no, time, name)
	time = hTime(time)
	if type(no) == 'table' then
		time = hTime(no.startTime)
		name = no.cpString
		no = no.no
	end

	no = string.format('%02i', no)
	return ("CHAPTER"..no..'='..time..
			  '\n'..
			  "CHAPTER"..no..'NAME='..name..
			  '\n')
end

--------- Aegisub's GUI ---------
local types = {
	[".txt (OGG/OGM)"] = "OGG/OGM txt files (.txt)|.txt|All Files (.)|.",
}
function show()
	local GUI = {
		label = {
			class = "label",
			label = "File extension: ",

			x = 1,
		},

		dropMenu = {
			class = "dropdown",
			name  = "dropdown",

			items = {
				".txt (OGG/OGM)",
			},
			value = ".txt (OGG/OGM)",

			x = 2,
		}
	}

	return aegisub.dialog.display(GUI, {"&Save", "&Cancel"}, {save = "&Save", cancel = "&Cancel"})
end

function save(lp, ln, lt)
	return aegisub.dialog.save("Save Chapter", lp or '', ln or 'Chapter.txt', lt or '')
end

--------- Aegisub's modules ---------
local sett = {}
sett.path = aegisub.decode_path("?user/ChapterGen.setting")

function sett.writeSett(d)
	if not io.open(sett.path, 'r') then
		io.open(sett.path, 'w'):close()
	end
	local ldas = io.open(sett.path, 'r'):read('*a')
	local file = io.open(sett.path, 'w')

	local ldat = {}
	for i, v in ldas:gmatch('(.-)%s*=%s*(.-)\n') do
		ldat[i] = v
	end

	for i, v in pairs(d) do
		ldat[i] = v
	end

	for i, v in pairs(ldat) do
		file:write(i..' = '..v..'\n')
	end

	file:close()
end

function sett.readSett(f)
	if not io.open(sett.path, 'r') then
		io.open(sett.path, 'w'):close()
		return {}
	end

	local s = io.open(sett.path, 'r'):read('*a')
	local data = {}

	for i, v in s:gmatch('(.-)%s*=%s*(.-)\n') do
		data[i] = v
	end

	return data[f] or data
end


local function OGMParser(lines)
	local str = ''

	local obj
	for i, line in ipairs(lines) do
		obj = newChapter{cpString = line.content, startTime = line.startTime}

		obj.no = i
		str = str.. OGMAssembler(obj)
	end
	obj = nil

	return str
end


function macro(lines)
	local b, data = show()
	if not b then aegisub.cancel() end

	local fLines = {}

	for _, v in ipairs(lines) do
		if v.class == "dialogue" and v.comment
			and v.effect:lower():find("chapter") then
				-- TODO: Proccess GUI Data
				table.insert(fLines, {
				content = v.text,
				startTime = v.start_time,
			})
		end
	end

	local ot = OGMParser(fLines)

	local ld = sett.readSett()
	local op = save(ld.lastUsedPath, ld.lastUsedName, types[data.dropdown])
	if not op then aegisub.cancel() end

	local file = assert(io.open(op, 'wb'), "Can't create this file")
	sett.writeSett{
		lastUsedPath = op,
		lastUsedName = op:gsub('(.-)\\', ''),
	}

	file:write(ot)
	file:close()
end

aegisub.register_macro(script_name, script_description, macro)
