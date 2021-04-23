-- See Copyright Notice in license.html
-- Based on Luiz Henrique de Figueiredo's lxml:
-- http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lxml

local lxp = require "lxp"

local table = require"table"
local tinsert, tremove = table.insert, table.remove
local assert, pairs, tostring, type = assert, pairs, tostring, type

-- auxiliary functions -------------------------------------------------------
local function starttag (p, tag, attr)
	local stack = p:getcallbacks().stack
	local newelement = {[0] = tag}
	for i = 1, #attr do
		local attrname = attr[i]
		local attrvalue = attr[attrname]
		newelement[attrname] = attrvalue
	end
	tinsert(stack, newelement)
end

local function endtag (p, tag)
	local stack = p:getcallbacks().stack
	local element = tremove(stack)
	assert(element[0] == tag, "Error while closing element: table[0] should be `"..tostring(tag).."' but is `"..tostring(element[0]).."'")
	local level = #stack
	tinsert(stack[level], element)
end

local function text (p, txt)
	local stack = p:getcallbacks().stack
	local element = stack[#stack]
	local n = #element
	if type(element[n]) == "string" and n > 0 then
		element[n] = element[n] .. txt
	else
		tinsert(element, txt)
	end
end

-- main function -------------------------------------------------------------
local function parse (o)
	local c = {
		StartElement = starttag,
		EndElement = endtag,
		CharacterData = text,
		_nonstrict = true,
		stack = {{}},
	}
	local p = lxp.new(c)
	if type(o) == "string" then
		local status, err, line, col, pos = p:parse(o)
		if not status then return nil, err, line, col, pos end
	else
		for l in pairs(o) do
			local status, err, line, col, pos = p:parse(l)
			if not status then return nil, err, line, col, pos end
		end
	end
	local status, err, line, col, pos = p:parse() -- close document
	if not status then return nil, err, line, col, pos end
	p:close()
	return c.stack[1][1]
end

-- utility functions ---------------------------------------------------------
local function compact (t) -- remove empty entries
	local n = 0
	for i = 1, #t do
		local v = t[i]
		if v then
			n = n+1
			if n ~= i then
				t[n] = v
				t[i] = nil
			end
		else
			t[i] = nil
		end
	end
end

local function clean (t) -- remove empty strings
	for i = 1, #t do
		local v = t[i]
		local tv = type(v)
		if tv == "table" then
			clean (v)
		elseif tv == "string" and v:match"^%s*$" then
			t[i] = false
		end
	end
	compact (t)
end

local function torecord (t) -- move 1-value subtables to table entries
	for i = 1, #t do
		local v = t[i]
		if type(v) == "table" then
			if #v == 1 and type(v[1]) == "string" and t[v[0]] == nil then
				t[v[0]] = v[1]
				t[i] = false
			else
				torecord (v)
			end
		end
	end
	compact (t)
end

return {
	clean = clean,
	compact = compact,
	parse = parse,
	torecord = torecord,
}
