--[[This script is under MIT license]]
script_name			= "Chapter Genrator"
script_namespace	= "ChapterGen.lua"
script_description= "Generates chapter files from line's timeline."
script_version		= '1.3.1'
script_author		= "Bilal Bassam, Bilal2453@github.com"
script_modified 	= "3 September 2019"

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

function show(sel)
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
				'.xml (Matroska Chapters)',
			},
			value = sel or ".txt (OGG/OGM)",

			x = 2,
		}
	}

	return aegisub.dialog.display(GUI, {"&Save", "&Cancel"}, {save = "&Save", cancel = "&Cancel"})
end

function save(lp, ln, lt)
	return aegisub.dialog.save("Save Chapter", lp or '', ln or 'Chapter', lt or '')
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


local function parseInput(tx)
	local options = {
		flaghidden = 'boolean',
		lang = 'string',
	}
	local oInput = {}

	for n, v in tx:gmatch('%-(.-):%s*(.-)%-') do
		-- Uhh, this is ugly...
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

-- Maps between file extensions and Writers
local wToS = {
	['.txt (OGG/OGM)'] = OGMWriter,
	['.xml (Matroska Chapters)'] = XMLWriter,
}

function macro(lines)
	local fLines = {}

	local iTable
	for _, v in ipairs(lines) do
		if v.class == "dialogue" and v.comment
		and v.effect:lower():find("chapter") then
			iTable = {
				cpString 	= v.text,
				startTime 	= v.start_time,
				endTime		= v.end_time,
			}

			for i, n in pairs(parseInput(v.effect:lower())) do
				iTable[i] = n
			end

			table.insert(fLines, iTable)

		end
	end

	if #fLines < 1 then
		error('No chapter lines were found !!')
	end

	local rSett = sett.readSett()

	local b, data = show(rSett.lastUsedExt)
	if not b then aegisub.cancel() end

	local tData = wToS[data.dropdown](fLines)

	local saveFile = save(rSett.lastUsedPath, rSett.lastUsedName, types[data.dropdown])
	if not saveFile then aegisub.cancel() end

	local file = io.open(saveFile, 'wb')
	if not file then error("Can't create the chapter file\nPlease try choose another directory") end

	sett.writeSett{
		lastUsedPath	= saveFile,
		lastUsedName	= saveFile:gsub('.-\\(.-)%..+', '%1'),
		lastUsedExt		= data.dropdown,
	}

	file:write(tData)
	file:close()
end

aegisub.register_macro(script_name, script_description, macro)
