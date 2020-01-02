--[[
	This script is under MIT license
	For more details, please read this
	https://github.com/Bilal2453/Chapter-Genrator/blob/master/LICENSE

	For instructions about using this plugin
	https://github.com/Bilal2453/Chapter-Genrator/blob/master/readme

	TODO: Support chapter merging on MacOS & Linux
	-- ?BUG: Does '?data/automation/include/' directory exists on MacOS? Can't tell...
		-- If not, please open an issue on github
]]

script_name			= "Chapters Generator"
script_namespace	= "Bilal2453.Chapters-Generator"
script_description= "Generates Video's Chapters Using Aegisub's Timeline."
script_version		= '2.5.0'
script_author		= "Bilal Bassam, Bilal2453@github.com"
script_modified	= "1 January 2020"

local settingsCheckboxes = {}
local dp = aegisub.decode_path
local mkvmergePath = dp'?data/automation/include/mkvmerge.exe'
local mkvpropeditPath = dp'?data/automation/include/mkvpropedit.exe'


local function fileExists(path)
	return io.open(path, 'r') and true or false
end

local function escapePath(path)
	if jit.os == "Windows" then
		return path:gsub('/', '\\\\'):gsub('\\', '\\\\')
	else
		return path:gsub('/', '\\/')
	end
end

-- I might remove this function, it isn't really needed
local function newChapter(startTime, endTime, cpString, flaghidden, lang)
	local tO = type(startTime) == 'table'
	return {
		endTime 		= tO and startTime.endTime or endTime,
		cpString 	= tO and startTime.cpString or cpString,
		lang 			= tO and startTime.lang or lang,
		flaghidden 	= tO and startTime.flaghidden or flaghidden,
		startTime 	= tO and startTime.startTime or startTime,
	}
end

local function hTime(time)
	if not time then return '' end
	local hours, mins, secs, ms

	hours	= math.floor((time / 1000) / 3600)
	mins	= math.floor((time / 1000 % 3600) / 60)
	secs	= math.floor((time / 1000) % 60)
	ms		= math.floor((time % 1000))

	return ('%02i:%02i:%02i.%03i'):format(hours, mins, secs, ms)
end

local function OGMAssembler(num, time, name)
	time = hTime(time)
	if type(num) == 'table' then
		time = hTime(num.startTime)
		name = num.cpString
		num = num.num
	end

	return ("CHAPTER%02i=%s\nCHAPTER%02iNAME=%s\n"):format(num, time, num, name)
end

local function XMLAssembler(obj)
	local endTime = obj.endTime > obj.startTime and hTime(obj.endTime)
	endTime = endTime and ('\n\t\t\t<ChapterTimeEnd>%s</ChapterTimeEnd>'):format(endTime) or ''

	local startTime = hTime(obj.startTime)
	local cpString = obj.cpString or ''
	local lang = type(obj.lang) == 'string' and obj.lang or 'und'
	local flaghidden = obj.flaghidden and 1 or 0


	return ("\n\t\t<ChapterAtom>\n\t\t\t<ChapterTimeStart>%s</ChapterTimeStart>%s\n\t\t\t<ChapterFlagHidden>%d</ChapterFlagHidden>\n\t\t\t<ChapterDisplay>\n\t\t\t\t<ChapterString>%s</ChapterString>\n\t\t\t\t<ChapterLanguage>%s</ChapterLanguage>\n\t\t\t</ChapterDisplay>\n\t\t</ChapterAtom>")
		:format(startTime, endTime, flaghidden, cpString, lang)
end

---------------------------------

local sett = {}
sett.path = dp('?user/ChapterGen.settings')

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
	local s = file:read('*a'); file:close();

	local data = {}
	for i, v in s:gmatch('(.-)%s*=%s*(.-)\n') do
		data[i] = v
	end

	return (sel and data[sel]) or (not sel and data)
end

function sett.readBol(sel)
	if not settingsCheckboxes[sel] then return end -- No settings were found

	local results = sett.readSett(sel)
	return (results and results ~= 'false') or (not results and settingsCheckboxes[sel].value)
end

function sett.writeSett(d)
	sett.createSettFile()

	local ldat = sett.readSett()
	local file = io.open(sett.path, 'w')

	for i, v in pairs(d) do
		if v == 'nil' then v = nil end
		if i and i ~= '' then
			ldat[i] = v
		end
	end

	for i, v in pairs(ldat) do
		file:write(i..' = '.. tostring(v)..'\n')
	end

	file:close()
end

-- Remove old settings files, so some updates can take effect
if sett.readSett('lastUsedVersion') ~= script_version then
	-- Old versions were using these paths
	os.remove(dp('?user/ChapterGen.setting'))
	os.remove(dp('?user/ChapterGen.config'))
	os.remove(dp('?user/config/ChapterGen.setting'))

	-- Delete default settings file and re-create it
	os.remove(sett.path)
	sett.createSettFile()

	sett.writeSett{lastUsedVersion = script_version}
end

---------  ---------

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
				oInput[n] = tonumber(v) == 1 or tonumber(v) == 0 and false
			elseif tonumber(v) and options[n] == 'number' then
				oInput[n] = tonumber(v)
			elseif options[n] == 'string' and not tonumber(v) then
				oInput[n] = v
			else
				error_dialog("Invalid value '%s' for argument '%s'\nvalue type must be a %s",
					v, n, options[n]..' (1 or 0)')
			end
		else
			error_dialog('Unknown Argument "%s"', n)
		end

	end

	return oInput
end

local function OGMWriter(lines)
	local str = ''

	local obj
	for i, line in ipairs(lines) do
		obj = newChapter(line)

		obj.num = i
		str = str.. OGMAssembler(obj)
	end

	return str
end

local function XMLWriter(lines)
	local str = ('<?xml version="1.0"?>\n<!-- <!DOCTYPE Chapters SYSTEM "matroskachapters.dtd"> -->\n<Chapters>\n\t<EditionEntry>')

	for _, line in ipairs(lines) do
		str = str.. XMLAssembler(newChapter(line))
	end

	return str.. '\n\t</EditionEntry>\n</Chapters>'
end

---------  ---------

-- All supported extensions
local extensions = {
	['.txt (OGG/OGM)'] = {
		writer = OGMWriter,
		GUIText = "OGG/OGM text (.txt)|.txt|All Files (.)|.",
		ext = ".txt",
	},
	['.xml (Matroska Chapters)'] = {
		writer = XMLWriter,
		GUIText = "Matroska Chapters (.xml)|.xml|All Files (.)|.",
		ext = ".xml",
	},
}

extensions.allNames = (function()
	local s = {}
	for i,_ in pairs(extensions) do table.insert(s, i) end
	return table.sort(s) or s
end)()

extensions.getAt = function(n)
	return extensions[extensions.allNames[n]]
end

local function createCheckbox(name, label, hint, defaultValue)
	 name, label, hint = name or #settingsCheckboxes+1, tostring(label), tostring(hint)
	 local self = {label = label, hint = hint, value = defaultValue and defaultValue}

	settingsCheckboxes[name] = self
end

createCheckbox('ignoreValidityRules', 'Ignore Validity Rules', "This option Makes the Plug-in Treat all Lines as they had 'chapter' Written inside the Effect Field and as they're Comments.\n\nRecommended when Using Aegisub only for Chapters without Subtitles.")
createCheckbox('useSelectedLines', 'Use Selected Lines', "This would Make the Plug-in Use Selected Lines when there's and Ignores everything else.\n\nBy Default it Doesn't Ignore validity Rules.", true)
createCheckbox('deleteLinesAfterExport', 'Delete Lines After Exporting', "This will Delete Chapter Lines that have been Used after Exporting the Chapters.\n\nTo Restore Deleted Lines, Undo Changes.")
createCheckbox('saveLastUsedPath', 'Remember Last Used Path', "Saves the Last Directory You Used to Export the Chapters, Also Saves the Last Used 'Extension'.", true)
createCheckbox('ignoreEndTime', 'Ignore End Time', "Don't Use End Time, So only Start Time would be Used and Written.\n\nUseful when Using 'XML/Matroska extension.'")
createCheckbox('askBeforeConverting', 'Ask Before Convert to MKV', "Asks you to Convert non-supported Videos to MKV before Merging Start.\nNote that only MKV Videos Can have Chapters\n\nUncheck this Box to Convert Videos without Asking.", true)

function show_export_ext(sel)
	local db = sett.readSett('dialogExtentionBehavior')
	if db and db:match('".*"$') then
		return true, {dropdown = db:match('"(.-)"$')}
	end

	local lastUsedExt = sett.readSett('lastUsedExt')
	local dialog = {
		{class = "label", label = "File extension: ", x = 1},
		dropMenu = {
			class = "dropdown",
			name  = "dropdown",
			items = extensions.allNames,
			value = (sel or extensions[lastUsedExt] and lastUsedExt)
				or extensions.allNames[1],
			x = 2,
		}
	}

	return aegisub.dialog.display(dialog, {"&Save", "&Cancel"}, {save = "&Save", cancel = "&Cancel"})
end

function info_dialog(tx, buttons, ...)
	local args = {...}
	args = #args < 1 and {''} or args
	buttons = buttons or {close = "Close"}

	tx = tx and tostring(tx) or "Unknown Error"
	tx = string.format(tx, table.unpack(args))

	local txSt = ''
	for i in tx:gmatch('[^\n]+') do
		txSt = txSt..i..string.rep(' ', 6)..'\n'
	end
	tx = txSt; txSt = nil;

	local dialogT = {
		label = {
			class = "label",
			label = tx,
			x = 1,
		}
	}

	local buttonsNames = {}
	for _, n in pairs(buttons) do
		table.insert(buttonsNames, n)
	end

	return aegisub.dialog.display(dialogT, buttonsNames, buttons)
end

function error_dialog(tx, ...)
	info_dialog(tx, ...)
	aegisub.cancel()
end

function settings_gui()
	local db = sett.readSett('dialogExtentionBehavior')
	local gui = {
		{class='label',label='Chapter Extention Dialog Behavior',x=1,y=0},
		dialogExtentionBehavior = {
			name = 'dialogExtentionBehavior',
			class = 'dropdown',
			items = {'Always Ask'},
			hint = "Always Ask: Always Ask about the Chapter's Extension before Exporting.\nOther Values: Never Ask, Use the Chosen Value Instead.",
			x = 1, y = 1,
		}
	}

	-- Set extensions names as values (for the dropmenu)
	for _, q in ipairs(extensions.allNames) do
		table.insert(gui.dialogExtentionBehavior.items, q)
	end
	gui.dialogExtentionBehavior.value = extensions[db] and db or 'Always Ask'

	-- Merge 'GUI' table with 'settingsCheckboxes' table
	local i = 4
	for q, v in pairs(settingsCheckboxes) do
		v.name, v.class = q, "checkbox"
		v.x, v.y = 1, i - 1
		v.value = sett.readBol(v.name)
		v.label = ' '.. v.label

		table.insert(gui, v)
		i = i + 1
	end

	return aegisub.dialog.display(gui)
end

---------  ---------

local function setLastUsedPath(path, ext)
	if sett.readBol('saveLastUsedPath') then
		if type(path) == 'string' then
			sett.writeSett {
				lastUsedPath = path:gsub('(.+%p).-%..+', '%1'),
				lastUsedName = path:gsub('.+%p(.-)%..+', '%1'),
			}
		end
		if extensions[ext].ext then
			sett.writeSett {
				lastUsedExt	= ext,
			}
		end
	end
end

local function getFileExt(path)
	return path:match('.+(%..-)$'):lower()
end

local function isExtSupported(ext)
	local supEx = "*.mkv;*.mp4;*.m4v;*.ts;*.m2ts;*.mts;*.ogg;*.ogm;*.ogv;*.webm;*.webmv;*.mpv;*.mpg;*.mpeg;*.m1v;*.m2v;*.evo;*.evob;*.vob;*.rmvb;*.avi;*.mov;*.3gp;*.flac;*.flv";
	for exten in supEx:gmatch('%*(%..-);') do
		if exten:lower() == tostring(ext):lower():match('(%..-)$') then return true end
	end

	return (ext and false) or (not ext and supEx) -- if ext is nil return all supported exts
end


local function executeMKVTools(tool, ...)
	tools = {['mkvmerge'] = mkvmergePath, ['mkvpropedit'] = mkvpropeditPath}
	tool, tools = tools[tool], tool -- Change 'tools' to the name of the tool

	if not fileExists(tool) then return false, ("%s Is Missing\nPlease Make sure %s does Exists at 'automation/include/' then Try again"):format(tools,tools) end
	local args = {...}; args = type(args[1]) == "table" and args[1] or args

	local jsonPath = dp('?temp/%s-flags.json'):format(tools)
	local jsonFile = io.open(jsonPath, "w")
	jsonFile:write('[\n')

	for i, v in ipairs(args) do
		jsonFile:write('\t"'..escapePath(v)..'"'..(i == #args and '\n' or ',\n'))
	end

	jsonFile:write(']')
	jsonFile:close()

	local success, errMesg, errCode = os.execute(('"%s" @%s'):format(tool, jsonPath))
	if not success then return false, errMesg, errCode end

	success, errMesg = os.remove(jsonPath)
	if not success then
		aegisub.debug.out('Warning: Attempt to remove a temporary file:\n'.. jsonPath.. '\n'.. errMesg.. '\n\n')
	end

	return true
end

local function mkvmerge(...)
	return executeMKVTools('mkvmerge', ...)
end

local function mkvpropedit(...)
	return executeMKVTools('mkvpropedit', ...)
end


local function convertVideoToMKV(sourcePath, targetPath)
	if getFileExt(sourcePath) == '.mkv' then return false, "The Video is already .MKV !!" end

	sourcePath = tostring(sourcePath) or ""
	targetPath = targetPath or sourcePath:gsub('%..-$', '.mkv')

	local success, err, code = mkvmerge{sourcePath, "--compression", "-1:none", "-o", targetPath}

	if not success then return success, err, code
	else return success, targetPath end
end

local function generateChapterFile(lines, selected, targetPath, ext)
	local cLines = {}
	local iLines = {}
	local iTable

	local useSelectedLines = sett.readBol('useSelectedLines')
	local ignoreValidityRules = sett.readBol('ignoreValidityRules')
	local ignoreEndTime = sett.readBol('ignoreEndTime')

	if useSelectedLines then
		selected.n = #selected -- A table with holes... what a great idea !
		for i, v in ipairs(selected) do selected[i] = nil; selected[v] = true end
	end

	-- Filtering sub lines
	for i, v in ipairs(lines) do
		if v.class == "dialogue" and (ignoreValidityRules or (v.comment and v.effect:lower():find("chapter"))) and (useSelectedLines and (selected.n > 1 and selected[i] or selected.n <= 1) or not useSelectedLines) then
			-- Create a (similar) chapter object
			iTable = {
				cpString = v.text,
				startTime= v.start_time,
				endTime	= ignoreEndTime and v.start_time or v.end_time,
			}

			-- Handle additional user inputs
			for k, n in pairs(parseInput(v.effect:lower())) do
				iTable[k] = n
			end

			table.insert(cLines, iTable)
			table.insert(iLines, i)
		end
	end

	if #cLines < 1 then
		return false, "No Chapters were found, Are you sure you aren't drunk ?"
	end

	local tData = extensions[ext].writer(cLines)

	-- Write the chapter file
	local file = io.open(targetPath, 'wb')
	if not file then return false, "Cannot Create the Chapter File\nPlease try Choosing another Directory for the File." end

	file:write(tData)
	file:close()

	-- Delete filtered Lines if user chooses to
	if sett.readBol('deleteLinesAfterExport') then
		lines.delete(iLines)
	end

	return tData
end

local function exportChapterToVideo(lines, selected, videoSource, ext)
	if not fileExists(mkvpropeditPath) then
		return false, "mkvpropedit Is Missing\nPlease Make sure mkvpropedit does Exists at 'automation/include/' then Try again"
	end

	if not isExtSupported(videoSource) then
		return false, ("Cannot Convert %s Video to .MKV (Matroska) Video.\nPlease Convert the Video to MKV then Try Again."):format(getFileExt(videoSource):upper())
	end

	if getFileExt(videoSource) ~= ".mkv" then
		local s = sett.readBol("askBeforeConverting")
		local b = s and info_dialog("The video isn't .MKV (Matroska).\nTo process the Video with chapters the Video has to be a Matroska.\nThe Plug-in will Create a copy of the Video and Convert it to Matroska.\n\nDo you want to Convert the Video to Matroska ?\n(NOTE: Processing time depends on the Video and on your Computer's processor.)",
			{yes = "Convert", cancel = "Cancel"})

		if (not b and s) or b == "Cancel" then
			aegisub.cancel()
		elseif not s or b then
			local success, videoOrErr, code = convertVideoToMKV(videoSource)
			if not success then return success, 'Error: '..tostring(videoOrErr)..'\nError code: '..tostring(code) end

			videoSource = videoOrErr
		end
	end

	local tmpChapPath = dp('?temp/tmp_chapter'..extensions[ext].ext)

	local s, e = generateChapterFile(lines, selected, tmpChapPath, ext)
	if not s then return false, e end

	local success, err, code = mkvpropedit{videoSource, "--chapters", tmpChapPath}
	if not success then
		aegisub.debug.out("Error: Merging Failed !\nPlease make sure that you have all required permissions and the video's extension is actually supported\n")
		aegisub.debug.out("If you can't fix this issue, please report it on github at 'Bilal2453/Chapter-Generator'\n")
		aegisub.debug.out('Status: '..tostring(err)..' | '.. 'Error Code: '..tostring(code)..' | mkvpropedit: '..tostring(fileExists(mkvpropeditPath))..'\n\n')
	end

	s, e = os.remove(tmpChapPath)
	if not s then
		aegisub.debug.out('Warning: Attempt to remove a temporary file: '.. tmpChapPath.. '\n'.. e.. '\n')
	end
	return success, tostring(err).. '\nError Code: '.. tostring(code)
end

---------  ---------

function macro_export_as(lines, selectedLines)
	local rSett = sett.readSett()

	local b, data = show_export_ext()
	if not b then aegisub.cancel() end

	local chapterExt = extensions[data.dropdown] and extensions[data.dropdown].ext
	local saveFile = aegisub.dialog.save("Export Chapter", rSett.lastUsedPath or '', rSett.lastUsedName or 'Chapter', chapterExt or extensions.getAt(1).ext)
	if not saveFile then aegisub.cancel() end

	setLastUsedPath(saveFile, data.dropdown)

	local s, err = generateChapterFile(lines, selectedLines, saveFile, data.dropdown)
	if not s then error_dialog(err) end
end

function macro_export_to_video(lines, selectedLines)
	local button, ext = show_export_ext()
	if not button then aegisub.cancel() end
	ext = ext.dropdown

	local videoSource = aegisub.dialog.open('Choose a video...', sett.readSett('lastUsedPath') or '', '', 'All supported videos|'..isExtSupported()..';*;', false, true)
	if not videoSource then aegisub.cancel() end

	setLastUsedPath(nil, ext)

	local success, mesg = exportChapterToVideo(lines, selectedLines, videoSource, ext)
	if not success then error_dialog(mesg) end
end

function macro_export_to_opened_video(lines, selectedLines)
	local button, chapterExt = show_export_ext()
	if not button then aegisub.cancel() end

	chapterExt = chapterExt.dropdown
	setLastUsedPath(nil, chapterExt)

	local videoSource = aegisub.project_properties()['video_file']
	if not videoSource then error_dialog("Cannot get Video's Path... believe me Aegisub is weird !\nTechniclly, it's impossible to get this Error, So Please Report This at github.com/Bilal2453/Chapter-Generator") end

	local supported = isExtSupported(videoSource)

	if not supported then error_dialog("Unsupported videos' extension.\nPlease, Convert the Video to MKV then Try Again.") end

	local success, mesg = exportChapterToVideo(lines, selectedLines, videoSource, chapterExt)
	if not success then error_dialog(mesg) end
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

---------  ---------

function is_video_opened()
	local p = aegisub.project_properties()
	if not p.video_file or p.video_file == '' or p.video_file:find("?dummy") then
		return false
	else
		return true
	end
end

aegisub.register_macro(script_name..'/Export/Export As...', "Exports Chapters as a File.", macro_export_as)
aegisub.register_macro(script_name..'/Export/Export To Video...', "Exports Chapters directly to a Video.", macro_export_to_video)
aegisub.register_macro(script_name..'/Export/Export To Opened Video...', "Exports Chapters directly to the Opened Video.", macro_export_to_opened_video, is_video_opened)
aegisub.register_macro(script_name..'/Settings/Plugin Configs', 'Configure Plug-in Behavior.', macro_change_settings)
