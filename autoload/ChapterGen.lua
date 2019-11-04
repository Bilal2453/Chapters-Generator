--[[
	This script is under MIT license
	For more details, please read this
	https://github.com/Bilal2453/Chapter-Genrator/blob/master/LICENSE

	For instructions about using this plugin
	https://github.com/Bilal2453/Chapter-Genrator/blob/master/readme

	TODO: Merge OGM and XML assemblers in one function
]]
script_name			= "Chapter Generator"
script_namespace	= "Bilal2453.Chapter-Generator"
script_description= "Generates chapter files from line's timeline."
script_version		= '2.1.0'
script_author		= "Bilal Bassam, Bilal2453@github.com"
script_modified	= "1 October 2019"

local settingCheckboxes = {
	ignoreValidityRules = {
		label	= "Ignore Validity Rules",
		hint	= "This makes the plugin treat all lines as they had 'chapter' in effect field and comment box is checked\n\nOnly recommended if you are using the subtitle file for chapters without subs."
	},
	useSelectedLines = {
		label	= "Use selected lines",
		value	= true,
		hint	= "This will use selected lines (only when found) as chapters when exporting and ignores everything else.\n\nDoesn't ignore validity rules by default."
	},
	deleteLinesAfterExport = {
		label	= "Delete Lines after Exporting",
		hint	= "This will delete lines that have been used to identify chapters, after exporting the chapter file.\n\nYou can undo changes (using ctrl+z by default) to restore deleted lines."
	},
	saveLastUsedPath = {
		value	= true,
		label	= "Remember last used Path",
		hint	= "Saves the last path used to export chapter file, Also saves the last used extension"
	},
	ignoreEndTime = {
		label	= "Ignore end time",
		hint	= "Ignores end time, so only start time will be writed and seted.\n\nUseful when using XML/Matroska extension."
	},
}

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

---------------------------------

local sett = {}
sett.path = aegisub.decode_path("?user/ChapterGen.settings")

function sett.createSettFile()
	if not io.open(sett.path, 'r') then
		io.open(sett.path, 'w'):close()
		return true
	end
	return false
end

function sett.readSett(sel)
	if sett.createSettFile() then
		return {}
	end

	local file = io.open(sett.path, 'r')
	local s = file:read('*a')
	local data = {}

	for i, v in s:gmatch('(.-)%s*=%s*(.-)\n') do
		data[i] = v
	end

	file:close() -- For some reason, Lua doesn't close it automatically

	return (sel and data[sel]) or (not sel and data)
end

function sett.readBol(sel)
	local results = sett.readSett(sel)

	return (results and results ~= 'false') or (not results and settingCheckboxes[sel].value)
end

function sett.writeSett(d)
	sett.createSettFile()

	local ldat = sett.readSett()
	local file = io.open(sett.path, 'w')

	for i, v in pairs(d) do
		if v == 'nil' then v = nil end
		ldat[i] = v
	end

	for i, v in pairs(ldat) do
		file:write(i..' = '.. tostring(v)..'\n')
	end

	file:close()
end

-- Remove old settings file, so some updates can take effect
if sett.readSett('lastUsedVersion') ~= script_version then
	-- Old plugin's version was using these paths
	os.remove(aegisub.decode_path('?user/ChapterGen.setting'))
	os.remove(aegisub.decode_path('?user/ChapterGen.config'))
	os.remove(aegisub.decode_path('?user/config/ChapterGen.setting'))

	-- Delete default settings file and recreate it
	os.remove(aegisub.decode_path('?user/ChapterGen.settings'))
	sett.createSettFile()

	sett.writeSett{lastUsedVersion = script_version}
end

--------- Aegisub's GUI ---------
local extToTiTypes = {
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
				".xml (Matroska Chapters)",
			},
			value = (sel or sett.readSett('lastUsedExt')) or ".txt (OGG/OGM)",

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

function settings_gui()
	local gui = {
	}

	local i = 1
	for q, v in pairs(settingCheckboxes) do
		v.name = q
		v.class = "checkbox"
		v.x = 1
		v.y = i - 1
		v.value = sett.readBol(v.name)
		v.label = ' '.. v.label

		table.insert(gui, v)
		i = i + 1
	end

	return aegisub.dialog.display(gui)
end

--------- Aegisub's modules ---------

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
					v, n, options[n]..' (1 or 0)')
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

-----------------------------------------------

local function setLastUsedPath(path, ext)
	if sett.readBol('saveLastUsedPath') then
		if type(path) == 'string' then
			sett.writeSett{
				lastUsedPath= path:gsub('(.+%p).-%..+', '%1'),
				lastUsedName= path:gsub('.+%p(.-)%..+', '%1'),
			}
		end
		if wToE[ext] then
			sett.writeSett{
				lastUsedExt	= ext,
			}
		end
	end
end

local function generateChapterFile(lines, selected, path, ext)
	local cLines = {}
	local iLines = {}

	local useSelectedLines = sett.readBol('useSelectedLines')

	-- This if statement is just to free memory if this feature isn't used
	if useSelectedLines then
		-- A table with holes... what a great idea !
		selected.n = #selected
		for i, v in ipairs(selected) do selected[i] = nil; selected[v] = true end
	end

	-- Filtering sub lines
	local iTable
	for i, v in ipairs(lines) do
		if v.class == "dialogue" and (sett.readBol('ignoreValidityRules') or (v.comment and v.effect:lower():find("chapter"))) and (useSelectedLines and (selected.n > 1 and selected[i] or selected.n <= 1) or not useSelectedLines) then
			-- TODO: Manage where i actually need to create the chapter object

			-- Create a chapter-like object
			iTable = {
				cpString = v.text,
				startTime= v.start_time,
				endTime	= sett.readBol('ignoreEndTime') and v.start_time or v.end_time,
			}

			for k, n in pairs(parseInput(v.effect:lower())) do
				iTable[k] = n
			end

			table.insert(cLines, iTable)
			table.insert(iLines, i)
		end
	end

	if #cLines < 1 then
		return false, "No chapters were found, Are you sure you aren't drunk ?"
	end

	local tData = wToS[ext](cLines)

	-- Write the chapter file
	local file = io.open(path, 'wb')
	if not file then return false, "Can't create the chapter file\nPlease try choosing another directory" end

	file:write(tData)
	file:close()

	-- Delete filtered Lines if user choose to
	if sett.readBol('deleteLinesAfterExport') then
		lines.delete(iLines)
	end

	return tData
end

local function exportChapToVideo(lines, selected, videoSource, ext)
	-- Any ideas about this fnc are more than welcomed

	local dp = aegisub.decode_path
	local temps = {}

	-- bug?: Does '?data/automation/include/' dir exists on MacOS? Can't tell...
	-- If not, please open an issue on github
	local mkvmerge = (dp'?data'.. '/automation/include/mkvmerge.exe')

	-- TODO: Better check for mkvmerge existent, this is awful
	if not io.open(mkvmerge, 'r') then
		return false, "mkvmerge.exe is missing\nPlease make sure mkvmerge.exe is in your automation/include dir then try again"
	end

	-- Should i change this to io.tmpfile() ?
	local tmpChapDir = (dp'?temp'..'/tmp_chapter'..wToE[ext])
	table.insert(temps, tmpChapDir)

	-- Create temporary chapter file
	local s, e = generateChapterFile(lines, selected, tmpChapDir, ext)
	if not s then return false, e end

	-- Will be used later in json options file
	local v1, v2, v3 = videoSource, tmpChapDir, videoSource:gsub('(%p.-)%..+', '%1_chap.mkv')

	if not sett.readBol('createVideoCopy') then
		v3 = videoSource:gsub('(%p.-)%..+', dp'?temp/'..'%1_tmp.mkv')
		table.insert(temps, v3)
	end

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
	local jsonPath = dp('?temp/chap-flags.json')
	table.insert(temps, jsonPath)

	-- Write options
	local jsonFile = io.open(jsonPath, 'w')
	jsonFile:write(('[\n"%s",\n"--compression",\n"-1:none",\n"--chapters",\n"%s",\n"-o",\n"%s"\n]'):format(v1, v2, v3))
	jsonFile:close()

	local a1, a2, a3 = os.execute('"'..mkvmerge..'" @'..jsonPath)
	if not a1 then
		aegisub.debug.out("Error: Muxing Failed !\nPlease make sure that you have all required permissions and the video's extension is actually supported\n")
		aegisub.debug.out("If you can't fix this problem, please report it on github at 'Bilal2453/Chapter-Genrator'\n")
		aegisub.debug.out('Status: '..tostring(a2)..' | '.. 'Error Code: '..tostring(a3)..'\n\n')
	end

	-- Remove all temporary files
	local success, err
	for _, path in ipairs(temps) do
		success, err = os.remove(path)
		if not success then
			aegisub.debug.out('Warning: attempt to remove a temporary file: '.. path.. '\n'.. err.. '\n')
		end
	end
	return true
end

-----------------------------------------------

function macro_export_as(lines, selectedLines)
	local rSett = sett.readSett()

	local b, data = show_export_ext(rSett.lastUsedExt)
	if not b then aegisub.cancel() end

	local saveFile = aegisub.dialog.save("Export Chapter", rSett.lastUsedPath or '', rSett.lastUsedName or 'Chapter', extToTiTypes[data.dropdown] or '')
	if not saveFile then aegisub.cancel() end

	setLastUsedPath(saveFile, data.dropdown)

	local s, err = generateChapterFile(lines, selectedLines, saveFile, data.dropdown)
	if not s then error(err) end
end

function macro_export_to_video(lines, selectedLines)
	local button, ext = show_export_ext()
	if not button then aegisub.cancel() end
	ext = ext.dropdown

	local videoSource = aegisub.dialog.open('Choose a video...', sett.readSett('lastUsedPath') or '', '', 'All supported videos|*.mkv;*.mp4;*.m4v;*.ts;*.m2ts;*.mts;*.ogg;*.ogm;*.ogv;*.webm;*.webmv;*.mpv;*.mpg;*.mpeg;*.m1v;*.m2v;*.evo;*.evob;*.vob;*.rmvb;*.avi;*.mov;*.3gp;*.flac;*.flv;*;', false, true)
	if not videoSource then aegisub.cancel() end

	setLastUsedPath(nil, ext)

	local success, mesg = exportChapToVideo(lines, selectedLines, videoSource, ext)
	if not success then error(mesg) end
end

function macro_export_to_opened_video(lines, selectedLines)
	local button, ext = show_export_ext()
	if not button then aegisub.cancel() end
	ext = ext.dropdown

	local supEx = "*.mkv;*.mp4;*.m4v;*.ts;*.m2ts;*.mts;*.ogg;*.ogm;*.ogv;*.webm;*.webmv;*.mpv;*.mpg;*.mpeg;*.m1v;*.m2v;*.evo;*.evob;*.vob;*.rmvb;*.avi;*.mov;*.3gp;*.flac;*.flv";
	local videoSource = aegisub.project_properties()['video_file']
	if not videoSource then error("Can't get video's path... believe me Aegisub is weird !") end

	local videoExt = videoSource:match('.+%p.-(%..+)')
	local supported = false

	for exten in supEx:gmatch('*(%..-);') do
		if exten == videoExt then supported = true; break end
	end

	setLastUsedPath(nil, ext)

	if not supported then error("Unsupported videos' extension.") end

	local success, mesg = exportChapToVideo(lines, selectedLines, videoSource, ext)
	if not success then error(mesg) end
end


function macro_change_settings()
	local button, data = settings_gui()
	if not button then aegisub.cancel() end

	sett.writeSett(data)

	-- Remove old used paths data
	if not sett.readBol('saveLastUsedPath') then
		sett.writeSett{
			lastUsedPath	= 'nil',
			lastUsedName	= 'nil',
			lastUsedExt		= 'nil',
		}
	end
end


function video_exists()
	local p = aegisub.project_properties()
	if not p.video_file or p.video_file == '' or p.video_file:find("?dummy") then
		return false
	else
		return true
	end
end

aegisub.register_macro(script_name..'/Export/Export As...', "Exports chapters as XML or TXT... file", macro_export_as)
aegisub.register_macro(script_name..'/Export/Export To Video...', "Exports Chapter file directly to a video. Note: this will copy the video and convert it to mkv", macro_export_to_video)
aegisub.register_macro(script_name..'/Export/Export To Opened Video', "Exports Chapter file directly to a video. Note: this will copy the video and convert it to mkv", macro_export_to_opened_video, video_exists)
aegisub.register_macro(script_name..'/Settings', '', macro_change_settings)
