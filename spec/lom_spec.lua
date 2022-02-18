local u_acute_utf8 = string.char(195)..string.char(186) -- C3 BA
local u_acute_latin1 = string.char(250) -- FA


describe("Lua object model: ", function()

	local lom
	before_each(function()
		lom = require "lxp.lom"
	end)

	describe("parse()", function()

		local tests = {
			{
				root_elem = [[<abc a1="A1" a2="A2">inside tag `abc'</abc>]],
				lom = {
					tag="abc",
					attr = { "a1", "a2", a1 = "A1", a2 = "A2", },
					"inside tag `abc'",
				},
			},
			{
				root_elem = [[<qwerty q1="q1" q2="q2">
	<asdf>some text</asdf>
</qwerty>]],
				lom = {
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
				root_elem = [[<ul><li>conteudo 1</li><li>conte]]..u_acute_utf8..[[do 2</li></ul>]],
				encoding = "UTF-8",
				lom = {
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
				root_elem = [[<ul><li>Conteudo 1</li><li>Conte]]..u_acute_latin1..[[do 2</li><li>Conte&uacute;do 3</li></ul>]],
				encoding = "ISO-8859-1",
				doctype = [[<!DOCTYPE test [<!ENTITY uacute "&#250;">]>]], -- Ok!
				lom = {
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
				root_elem = [[<ul><li>Conte&uacute;do</li></ul>]],
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
				lom = {
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


		for i, test in pairs(tests) do
			local encoding = test.encoding or "ISO-8859-1"
			local header = [[<?xml version="1.0" encoding="]]..encoding..[["?>]]..(test.doctype or '')
			local doc = header..test.root_elem

			it("test case " .. i .. ": string (all at once)", function()
				local o = assert(lom.parse(doc))
				assert.same(o, test.lom)
			end)

			it("test case " .. i .. ": iterator", function()
				local o = assert(lom.parse(string.gmatch(doc, ".-%>")))
				assert.same(o, test.lom)
			end)

		end

	end)



	local output
	local input = [[<?xml version="1.0"?>
		<a1>
			<b1>
				<c1>t111</c1>
				<c2>t112</c2>
				<c1>t113</c1>
			</b1>
			<b2>
				<c1>t121</c1>
				<c2>t122</c2>
			</b2>
		</a1>]]



	describe("find_elem()", function()

		it("returns element", function()
			local output = assert(lom.parse(input))
			local c1 = lom.find_elem (output, "c1")
			assert (type(c1) == "table")
			assert (c1.tag == "c1")
			assert (c1[1] == "t111")
		end)

	end)



	describe("list_children()", function()

		it("returns all children if no tag specified", function()
			local output = assert(lom.parse(input))
			local children = {}
			-- output[1] is whitespace before tag <b1>, output[2] is the table
			-- for <b1>.
			for child in lom.list_children(output[2]) do
				children[#children+1] = child.tag
			end
			assert.same({ "c1", "c2", "c1" }, children)
		end)


		it("returns all matching children if tag specified", function()
			local output = assert(lom.parse(input))
			local children = {}
			-- output[1] is whitespace before tag <b1>, output[2] is the table
			-- for <b1>.
			for child in lom.list_children(output[2], "c1") do
				children[#children+1] = child.tag
			end
			assert.same({ "c1", "c1" }, children)

			children = {}
			for child in lom.list_children(output[2], "c2") do
				children[#children+1] = child.tag
			end
			assert.same({ "c2" }, children)
		end)


		it("returns nothing when run on a text-node", function()
			local children = {}
			-- test on whitespace, typically before a tag
			for child in lom.list_children("          ") do
				children[#children+1] = child.tag
			end
			assert.same({}, children)
		end)

	end)

end)
