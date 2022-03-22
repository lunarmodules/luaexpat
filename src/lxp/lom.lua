-- See Copyright Notice in license.html

local table = require"table"
local tinsert, tremove = table.insert, table.remove
local assert, type = assert, type


-- auxiliary functions -------------------------------------------------------
local function starttag (p, tag, attr)
	local stack = p:getcallbacks().stack
	local newelement = {tag = tag, attr = attr}
	tinsert(stack, newelement)
end

local function endtag (p, tag)
	local stack = p:getcallbacks().stack
	local element = tremove(stack)
	assert(element.tag == tag)
	local level = #stack
	tinsert(stack[level], element)
end

local function text (p, txt)
	local stack = p:getcallbacks().stack
	local element = stack[#stack]
	local n = #element
	if type(element[n]) == "string" then
		element[n] = element[n] .. txt
	else
		tinsert(element, txt)
	end
end

-- main function -------------------------------------------------------------
local function parse (o, opts)
	local opts = opts or {}
	local c = { StartElement = starttag,
		EndElement = endtag,
		CharacterData = text,
		_nonstrict = true,
		stack = {{}}
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
local function find_elem (self, tag)
	if self.tag == tag then
		return self
	end
	for i = 1, #self do
		local v = self[i]
		if type(v) == "table" then
			local found = find_elem (v, tag)
			if found then
				return found
			end
		end
	end
	return nil
end

local function list_children (self, tag)
	local i = 0
	return function ()
		i = i+1
		local v = self[i]
		while v do
			if type (v) == "table" and (tag == nil or tag == v.tag) then
				return v
			end
			i = i+1
			v = self[i]
		end
		return nil
	end
end

return {
	find_elem = find_elem,
	list_children = list_children,
	parse = parse,
}
