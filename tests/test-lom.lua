#!/usr/local/bin/lua

local lom = require "lxp.lom"

local u_acute_utf8 = string.char(195)..string.char(186) -- C3 BA
local u_acute_latin1 = string.char(250) -- FA

local tests = {
	{
		[[<abc a1="A1" a2="A2">inside tag `abc'</abc>]],
		{
			tag="abc",
			attr = { "a1", "a2", a1 = "A1", a2 = "A2", },
			"inside tag `abc'",
		},
	},
	{
		[[<qwerty q1="q1" q2="q2">
	<asdf>some text</asdf>
</qwerty>]],
		{
			tag = "qwerty",
			attr = { "q1", "q2", q1 = "q1", q2 = "q2", },
			"\n\t",
			{
				tag = "asdf",
				attr = {},
				"some text",
			},
			"\n",
		},
	},
	{
		[[<ul><li>conteudo 1</li><li>conte]]..u_acute_utf8..[[do 2</li></ul>]],
		encoding = "UTF-8",
		{
			tag = "ul",
			attr = {},
			{
				tag = "li",
				attr = {},
				"conteudo 1",
			},
			{
				tag = "li",
				attr = {},
				"conteúdo 2",
			},
		},
	},
	{
		[[<ul><li>Conteudo 1</li><li>Conte]]..u_acute_latin1..[[do 2</li><li>Conte&uacute;do 3</li></ul>]],
		encoding = "ISO-8859-1",
		doctype = [[<!DOCTYPE test [<!ENTITY uacute "&#250;">]>]], -- Ok!
		{
			tag = "ul",
			attr = {},
			{
				tag = "li",
				attr = {},
				"Conteudo 1",
			},
			{
				tag = "li",
				attr = {},
				"Conteúdo 2", -- Latin-1 becomes UTF-8
			},
			{
				tag = "li",
				attr = {},
				"Conteúdo 3", -- entity becomes a UTF-8 character
			},
		},
	},
	{
		[[<ul><li>Conte&uacute;do</li></ul>]],
		--doctype = [[<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">]], --> ignora as entidades
		--doctype = [[<!DOCTYPE html SYSTEM "about:legacy-compat">]], --> ignora as entidades
		--doctype = [[<!DOCTYPE html>]], --> undefined entity
		--doctype = [[<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN">]], --> sintax error
		--doctype = [[<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN" SYSTEM "http://www.w3.org/TR/html4/strict.dtd">]], --> syntax error
		--doctype = [[<!DOCTYPE HTMLlat1 PUBLIC "-//W3C//ENTITIES Latin 1//EN//HTML">]], --> syntax error
		--doctype = [[<!DOCTYPE HTMLlat1 PUBLIC "-//W3C//ENTITIES Latin 1 for XHTML//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml-lat1.ent">]], --> ignora entidades
		--doctype = [[<!DOCTYPE isolat1 PUBLIC "//W3C//ENTITIES Added Latin 1//EN//XML" "http://www.w3.org/2003/entities/2007/isolat1.ent">]], --> ignora entidades
		doctype = [[<!DOCTYPE test [<!ENTITY uacute "&#250;">]>]], -- Ok!
		encoding = "UTF-8",
		{
			tag = "ul",
			attr = {},
			{
				tag = "li",
				attr = {},
				"Conteúdo", -- entity becomes a UTF-8 character
			},
		},
	},
}

function table.equal (t1, t2)
	for nome, val in pairs (t1) do
		local tv = type(val)
		if tv == "table" then
			if type(t2[nome]) ~= "table" then
				return false, "Different types at entry `"..nome.."': t1."..nome.." is "..tv.." while t2."..nome.." is "..type(t2[nome]).." ["..tostring(t2[nome]).."]"
			else
				local ok, msg = table.equal (val, t2[nome])
				if not ok then
					return false, "["..nome.."]\t"..tostring(val).." ~= "..tostring(t2[nome]).."; "..msg
				end
			end
		else
			if val ~= t2[nome] then
				return false, "["..nome.."]\t["..tostring(val).."] ~= ["..tostring(t2[nome])..']'
			end
		end
	end
	return true
end


for i, s in ipairs(tests) do
	io.write'.'
	local encoding = s.encoding or "ISO-8859-1"
	local header = [[<?xml version="1.0" encoding="]]..encoding..[["?>]]..(s.doctype or '')
	local doc = header..s[1]

	local o1 = assert (lom.parse (doc))
	assert(table.equal (o1, s[2]))

	local o2 = assert (lom.parse (string.gmatch(doc, ".-%>")))
	assert(table.equal (o2, s[2]))
end

local o = assert (lom.parse ([[
<?xml version="1.0"?>
<a1>
	<b1>
		<c1>t111</c1>
		<c2>t112</c2>
	</b1>
	<b2>
		<c1>t121</c1>
		<c2>t122</c2>
	</b2>
</a1>]]))
assert (o.tag == "a1")
assert (o[1] == "\n\t")
assert (o[2].tag == "b1")
assert (o[2][2].tag == "c1")
local c1 = lom.find_elem (o, "c1")
assert (type(c1) == "table")
assert (c1.tag == "c1")
assert (c1[1] == "t111")
local next_child = lom.list_children (o)
assert (next_child().tag == "b1")
assert (next_child().tag == "b2")
assert (next_child() == nil)

print"OK"
