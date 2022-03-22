-- See Copyright Notice in license.html
-- Based on Luiz Henrique de Figueiredo's lxml:
-- http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lxml

local table = require"table"
local tinsert, tremove = table.insert, table.remove
local assert, tostring, type = assert, tostring, type

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
	assert(element[0] == tag, "Error while closing element: table[0] should be `"..
		tostring(tag).."' but is `"..tostring(element[0]).."'")
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
local function parse (o, opts)
	local opts = opts or {}
	local c = {
		StartElement = starttag,
		EndElement = endtag,
		CharacterData = text,
		_nonstrict = true,
		stack = {{}},
	}

	local p
	if opts.threat then
		c.threat = opts.threat
		p = require("lxp.threat").new(c, opts.separator)
	else
		p = require("lxp").new(c, opts.separator)
	end

	local to = type(o)
	if to == "string" then
		local status, err, line, col, pos = p:parse(o)
		if not status then return nil, err, line, col, pos end
	else
		local iter
		if to == "table" then
			local i = 0
			iter = function() i = i + 1; return o[i] end
		elseif to == "function" then
			iter = o
		elseif to == "userdata" and o.read then
			iter = function()
				local l = o:read()
				if l then
					return l.."\n"
				end
			end
		else
			error ("Bad argument #1 to parse: expected a string, a table, a function or a file, but got "..to, 2)
		end
		for l in iter do
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
	return t
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
	return compact (t)
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
	return compact (t)
end

return {
	clean = clean,
	compact = compact, -- TODO: internal only, should not be exported
	parse = parse,
	torecord = torecord,
}
