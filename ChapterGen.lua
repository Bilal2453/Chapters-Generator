--[[
	This script is under MIT license
	For more details, please read this
	https://github.com/Bilal2453/Chapter-Genrator/blob/master/LICENSE

	TODO: "Options" or "Settings" GUI
	TODO: Settings system and handling for the settings GUI
]]
script_name			= "Chapter Genrator"
script_namespace	= "Bilal2453.Chapter-Genrator"
script_description= "Generates chapter files from line's timeline."
script_version		= '1.3.1'
script_author		= "Bilal Bassam, Bilal2453@github.com"
script_modified	= "11 September 2019"

local function newChapter(startTime, endTime, cpString, flaghidden, lang)
	local tO = type(startTime) == 'table'
	local o = {
		endTime 		= tO and startTime.endTime or endTime,
		cpString 	= tO and startTime.cpString or cpString,
		lang 			= tO and startTime.lang or lang,
		flaghidden 	= tO and startTime.flaghidden or flaghidden,
		startTime 	= tO and startTime.startTime or startTime,
	}

	return o
end

---------  ---------
local function hTime(time)
	if not time then return '' end
	local hours, mins, secs, ms

	hours	= math.floor((time / 1000) / 3600)
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

local function XMLAssembler(startTime, endTime, cpString, flaghidden, lang)
	if type(startTime) == 'table' then
		endTime		= startTime.endTime
		cpString		= startTime.cpString
		flaghidden	= startTime.flaghidden
		lang			= startTime.lang
		startTime	= startTime.startTime
	end

	endTime = endTime > startTime and hTime(endTime)
	endTime = endTime and ('\n\t\t\t<ChapterTimeEnd>%s</ChapterTimeEnd>'):format(endTime) or ''

	startTime = hTime(startTime)
	cpString = cpString or ''
	lang, flaghidden = type(lang or 1) == 'string' and lang or 'und', flaghidden and 1 or 0


	return ([[
		<ChapterAtom>
			<ChapterTimeStart>%s</ChapterTimeStart>%s
			<ChapterFlagHidden>%d</ChapterFlagHidden>
			<ChapterDisplay>
				<ChapterString>%s</ChapterString>
				<ChapterLanguage>%s</ChapterLanguage>
			</ChapterDisplay>
		</ChapterAtom>
	]]):format(startTime, endTime, flaghidden, cpString, lang)
end

--------- Aegisub's GUI ---------
local types = {
	[".txt (OGG/OGM)"] = "OGG/OGM text (.txt)|.txt|All Files (.)|.",
	[".xml (Matroska Chapters)"] = "Matroska Chapters (.xml)|.xml|All Files (.)|.",
}

function show_export_ext(sel)
	local dialog = {
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
				'.xml (Matroska Chapters)',
			},
			value = sel or ".txt (OGG/OGM)",

			x = 2,
		}
	}

	return aegisub.dialog.display(dialog, {"&Save", "&Cancel"}, {save = "&Save", cancel = "&Cancel"})
end

function error(tx, ...)
	local args = {...}
	args = #args < 1 and {''} or args

	tx = tx and tostring(tx) or "Unknown Error"
	tx = string.format(tx, table.unpack(args))

	aegisub.dialog.display({
		label = {
			class = "label",
			label = tx,
			x = 1,
			width = 10,
		}
	}, {"&Close"}, {close = "&Close"})
	aegisub.cancel()
end

--------- Aegisub's modules ---------

local sett = {}
sett.path = aegisub.decode_path("?user/ChapterGen.settings")

function sett.createSettFile()
	if not io.open(sett.path, 'r') then
		io.open(sett.path, 'w'):close()
		return true
	end
	return false
end

function sett.writeSett(d)
	sett.createSettFile()

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
	if sett.createSettFile() then
		return {}
	end

	local file = io.open(sett.path, 'r')
	local s = file:read('*a')
	local data = {}

	for i, v in s:gmatch('(.-)%s*=%s*(.-)\n') do
		data[i] = v
	end

	file:close() -- For some reason, Lua doesn't close it automaticly

	return (f and data[f]) or (not f and data)
end

-- Remove some files, including settings file, so some updates can take effect
if sett.readSett('lastUsedVersion') ~= script_version then
	os.remove(aegisub.decode_path('?user/ChapterGen.setting'))
	os.remove(aegisub.decode_path('?user/ChapterGen.config'))
	os.remove(aegisub.decode_path('?user/config/ChapterGen.setting'))

	os.remove(aegisub.decode_path('?user/ChapterGen.settings'))
	sett.createSettFile()

	sett.writeSett{lastUsedVersion = script_version}
end
--------------------------------

local function parseInput(tx)
	local options = {
		flaghidden = 'boolean',
		lang = 'string',
	}
	local oInput = {}

	for n, v in tx:gmatch('%-(.-):%s*(.-)%-') do
		-- Uhh, this is ugly...
		-- TODO: Better input handling
		if options[n] then
			if tonumber(v) and options[n] == 'boolean' then
				oInput[n] = tonumber(v) == 1 or false
			elseif tonumber(v) and options[n] == 'number' then
				oInput[n] = tonumber(v)
			elseif options[n] == 'string' and not tonumber(v) then
				oInput[n] = v
			else
				error("Invalid value '%s' for argument '%s'\nvalue type must be a %s",
					v, n, options[n])
			end
		else
			error("Unknown argument '%s'", n)
		end

	end

	return oInput
end

local function OGMWriter(lines)
	local str = ''

	local obj
	for i, line in ipairs(lines) do
		obj = newChapter(line)

		obj.no = i
		str = str.. OGMAssembler(obj)
	end
	obj = nil

	return str
end

local function XMLWriter(lines)
	local str = ('<?xml version="1.0"?>\n<!-- <!DOCTYPE Chapters SYSTEM "matroskachapters.dtd"> -->\n<Chapters>\n\t<EditionEntry>\n')

	for _, line in ipairs(lines) do
		str = str.. XMLAssembler(newChapter(line))
	end

	return str.. '\t</EditionEntry>\n</Chapters>'
end

-- Maps between file extensions and 'Writers' functions
local wToS = {
	['.txt (OGG/OGM)'] = OGMWriter,
	['.xml (Matroska Chapters)'] = XMLWriter,
}
-- Maps between file extension's name used in GUI and the real ext
local wToE = {
	['.txt (OGG/OGM)'] = '.txt',
	['.xml (Matroska Chapters)'] = '.xml',
}

local function generateFile(lines, path, ext)
	local fLines = {}
	
	local iTable
	for _, v in ipairs(lines) do
		if v.class == "dialogue" and v.comment
		and v.effect:lower():find("chapter") then
			iTable = {
				cpString = v.text,
				startTime= v.start_time,
				endTime	= v.end_time,
			}

			for i, n in pairs(parseInput(v.effect:lower())) do
				iTable[i] = n
			end

			table.insert(fLines, iTable)
		end
	end

	if #fLines < 1 then
		return false, "No chapters were found, Are you sure you aren't drunk ?"
	end

	local tData = wToS[ext](fLines)

	local file = io.open(path, 'wb')
	if not file then return false, "Can't create the chapter file\nPlease try choosing another directory" end

	file:write(tData)
	file:close()

	return tData
end

-----------------------------------------------

function macro_export_as(lines)
	local rSett = sett.readSett()
	
	local b, data = show_export_ext(rSett.lastUsedExt)
	if not b then aegisub.cancel() end
	
	local saveFile = aegisub.dialog.save("Export Chapter", rSett.lastUsedPath or '', rSett.lastUsedName or 'Chapter', types[data.dropdown] or '')
	if not saveFile then aegisub.cancel() end
	
	sett.writeSett{
		lastUsedPath	= saveFile:gsub('(.+%p).-%..+', '%1'),
		lastUsedName	= saveFile:gsub('.+%p(.-)%..+', '%1'),
		lastUsedExt		= data.dropdown,
		lastUsedVersion= script_version,
	}

	local s, err = generateFile(lines, saveFile, data.dropdown)
	if not s then error(err) end

	for i, v in ipairs(lines) do
		if v.class == "dialogue" and v.comment
		and v.effect:lower():find("chapter") then
			lines.delete(i)
		end
	end
end

function macro_export_to_video(lines)
	-- Any ideas about this fnc are more than welcomed

	local dp = aegisub.decode_path
	local temps = {}
	
	-- bug?: Does '?data/automation/include/' dir exists on MacOS? Can't tell...
	-- If not, please open an issue on github
	local mkvmerge = (dp'?data'.. '/automation/include/mkvmerge.exe')
	
	-- TODO: Better check for mkvmerge existens, this is awful
	if not io.open(mkvmerge, 'r') then error('mkvmerge.exe is missing\nPlease make sure mkvmerge.exe is in your automation/include dir then try again') end
	
	local setts = sett.readSett()

	local button, data = show_export_ext(setts.lastUsedExt)
	if not button then aegisub.cancel() end
	data = data.dropdown
	
	-- Should i change this to io.tmpfile() ?
	-- Or it sounds like a bad idea ? hmm...
	local tmpChapDir = (dp'?temp'..'/tmp_chapter'..wToE[data])
	table.insert(temps, tmpChapDir)

	local videoSource = aegisub.dialog.open('Choose a video...', '', setts.lastUsedPath, 'All supported videos|*.mkv;*.mp4;*.m4v;*.ts;*.m2ts;*.mts;*.ogg;*.ogm;*.ogv;*.webm;*.webmv;*.mpv;*.mpg;*.mpeg;*.m1v;*.m2v;*.evo;*.evob;*.vob;*.rmvb;*.avi;*.mov;*.3gp;*.flac;*.flv;*;', false, true)
	if not videoSource then aegisub.cancel() end

	-- Create temporary chapter file
	local s, e = generateFile(lines, tmpChapDir, data)
	if not s then error(e) end

	-- Will be used later in json options file
	local v1, v2, v3 = videoSource, tmpChapDir, videoSource:gsub('(%p.-)%.(.+)', '%1_chap.%2')
	if jit.os == "Windows" then
		-- \\+\\ = \\ escaped backslash to be used in the json file
		v1 = v1:gsub('/', '\\\\'):gsub('\\', '\\\\')
		v2 = v2:gsub('/', '\\\\'):gsub('\\', '\\\\')
		v3 = v3:gsub('/', '\\\\'):gsub('\\', '\\\\')
	else
		v1 = v1:gsub('/', '\\/')
		v2 = v2:gsub('/', '\\/')
		v3 = v3:gsub('/', '\\/')
	end

	-- Create temporary options file (so all platforms can be supported using only one commandline)
	-- Actually it is not really needed, but just in case.
	local jsonPath = dp'?temp/chap-flags.json'
	table.insert(temps, jsonPath)
	
	-- Write options
	local jsonFile = io.open(jsonPath, 'w')
	jsonFile:write(('[\n"%s",\n"--compression",\n"-1:none",\n"--chapters",\n"%s",\n"-o",\n"%s"\n]')
		:format(v1, v2, v3))
	jsonFile:close()

	local a1, a2, a3 = os.execute('"'..mkvmerge..'" @'..jsonPath)
	if not a1 then
		aegisub.debug.out("Error: Muxing Failed !\nPlease make sure you have required premisions and the video's extension is actually supported\n")
		aegisub.debug.out("If you can't solve this problem, please report it on github at 'Bilal2453/Chapter-Genrator'\n")
		aegisub.debug.out('Status: '..tostring(a2)..' | '.. 'Error Code: '..tostring(a3)..'\n\n')
	end

	-- Remove all temporary files
	local success, err
	for _, path in ipairs(temps) do
		success, err = os.remove(path)
		if not success then
			aegisub.debug.out('Error: attempt to remove a temporary file:\n'.. err.. '\n')
		end
	end
end

aegisub.register_macro(script_name..'/Export/Export As', "Exports chapters as XML or TXT... file", macro_export_as)
aegisub.register_macro(script_name..'/Export/Export To Video', "Exports Chapter file directly to a video. Note: this will copy the video and convert it to mkv", macro_export_to_video)
