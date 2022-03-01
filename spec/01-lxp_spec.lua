local d = require("pl.stringx").dedent or require("pl.text").dedent

local preamble = [[
<?xml version="1.0" encoding="ISO-8859-1"?>

<!DOCTYPE greeting [
  <!ENTITY xuxu "is this a xuxu?">

  <!ATTLIST to
     method  CDATA   #FIXED "POST"
  >

  <!ENTITY test-entity
           SYSTEM "entity1.xml">

  <!NOTATION TXT SYSTEM "txt">

  <!ENTITY test-unparsed SYSTEM "unparsed.txt" NDATA txt>

  <!ATTLIST hihi
      explanation ENTITY #REQUIRED>

  <!ENTITY % myParameterEntity "myElement | myElement2 | myElement3">
  <!ENTITY % emptyValue "">
]>
]]


describe("lxp:", function()

	local lxp

	-- create a test parser.
	-- table 'cbs' can contain array elements, where the values are callback
	-- names. The results of those callbacks will be stored in 'cbdata'.
	-- The hash part, can have callback names as keys, and callback functions
	-- as values.
	-- Returns the new parser object.
	local cbdata, _p
	local function test_parser(cbs, separator)
		assert(type(cbs) == "table", "expected arg #1 to be a table")
		local t = {}
		for k,v in pairs(cbs) do
			if type(k) == "number" then
				assert(type(v) == "string", "array entries must have string values")
				k = v
				v = function(p, ...)
					--assert(p == _p, "parser mismatch (self)")
					cbdata[#cbdata+1] = { k, ... }
				end

			elseif type(k) == "string" then
				assert(type(v) == "function", "string keys must have function values")

			else
				error("bad entry, expected string or numeric keys, got "..tostring(k))
			end
			assert(t[k] == nil, "key '"..k.."' was provided more than once")
			t[k] = v
		end

		cbdata = {}
		_p = lxp.new(t, separator)
		return _p
	end



	before_each(function()
		lxp = require "lxp"
	end)



	describe("basics", function()

		it("exports constants", function()
			assert.is.string(lxp._VERSION)
			assert.matches("^LuaExpat %d%.%d%.%d$", lxp._VERSION)
			assert.is.string(lxp._DESCRIPTION)
			assert.is.string(lxp._COPYRIGHT)
			assert.is.string(lxp._EXPAT_VERSION)
		end)


		it("exports 'new' constructor", function()
			assert.is_function(lxp.new)
		end)


		it("new() creates a working parser", function()
			local p = lxp.new{}
			p:setencoding("ISO-8859-1")
			assert(p:parse[[<tag cap="5">hi</tag>]])
			p:close()
		end)


		-- test based on https://github.com/tomasguisasola/luaexpat/issues/2
		it("reloads module if dropped", function()
			package.loaded.lxp = nil
			local first_lxp = require "lxp"
			assert.is_table(first_lxp)
			assert.is_function(first_lxp.new)

			package.loaded.lxp = nil
			local second_lxp = require "lxp"
			assert.is_table(second_lxp)
			assert.is_function(second_lxp.new)

			assert.not_equal(first_lxp, second_lxp)
		end)

	end)



	describe("_nonstrict", function()

		it("doesn't allow unknown entries if not set", function()
			assert.matches.error(function()
				lxp.new{ something = "something" }
			end, "invalid option 'something'")
		end)


		it("allows unknown entries if set", function()
			assert.no.error(function()
				lxp.new{
					_nonstrict = true,
					something = "something",
				}
			end)
		end)

	end)



	describe("getcallbacks()", function()

		it("returns the callbacks", function()
			local t = {}
			local p = lxp.new(t)
			assert.equal(t, p:getcallbacks())
		end)

	end)



	it("callbacks can be updated while parsing", function()
		local p = test_parser { "CharacterData" }
		assert(p:parse(preamble))
		assert(p:parse("<root><to>a basic text</to>"))

		assert.same({
			{ "CharacterData", "a basic text" },
		}, cbdata)

		-- update callback
		p:getcallbacks().CharacterData = "error"

		assert.matches.error(function()
			assert(p:parse("<to>a basic text</to></root>"))
		end, "lxp 'CharacterData' callback is not a function")
	end)



	describe("parsing", function()

		it("allows multiple finishing calls", function()
			local p = test_parser { "CharacterData" }
			assert(p:parse(preamble))
			assert(p:parse("<to>a basic text</to>"))
			assert(p:parse())
			assert.has.no.error(function()
				assert(p:parse())
			end)
			p:close()
		end)


		it("handles start/end tags", function()
			local p = test_parser { "StartElement", "EndElement" }
			assert(p:parse(preamble))
			assert(p:parse(d[[
				<to priority="10" xu = "hi">
			]]))

			assert.same({
				{ "StartElement", "to", {
						"priority", "xu",
						priority = "10",
						xu = "hi",
						method = "POST" }},
			}, cbdata)

			assert(p:parse("</to>"))
			assert(p:parse())
			p:close()

			assert.same({
				{ "StartElement", "to", {
						"priority", "xu",
						priority = "10",
						xu = "hi",
						method = "POST" }},
				{ "EndElement", "to" },
			}, cbdata)
		end)


		it("handles CharacterData/CDATA", function()
			local p = test_parser { "CharacterData" }
			assert(p:parse(preamble))
			assert(p:parse(d[=[
				<to>a basic text&lt;<![CDATA[<<ha>>]]></to>
			]=]))

			assert.same({
				{ "CharacterData", "a basic text<<<ha>>" },
			}, cbdata)

			assert(p:parse())
			p:close()
		end)


		it("handles CDATA sections", function()
			local p = test_parser { "CharacterData", "StartCdataSection", "EndCdataSection" }
			assert(p:parse(preamble))
			assert(p:parse"<to>")
			assert(p:parse"<![CDATA[hi]]>")
			assert(p:parse"</to>")
			p:close()

			assert.same({
				{ "StartCdataSection" },
				{ "CharacterData", "hi" },
				{ "EndCdataSection" },
			}, cbdata)
		end)


		it("handles Processing Instructions", function()
			local p = test_parser { "ProcessingInstruction" }
			assert(p:parse(preamble))
			assert(p:parse(d[[
				<to>
				  <?lua how is this passed to <here>? ?>
				</to>
			]]))
			p:close()

			assert.same({
				{ "ProcessingInstruction", "lua", "how is this passed to <here>? " },
			}, cbdata)
		end)


		it("handles Comments", function()
			local p = test_parser { "Comment", "CharacterData" }
			assert(p:parse(preamble))
			assert(p:parse(d[[
				<to>some text
				<!-- <a comment> with some & symbols -->
				some more text</to>]]
			))
			p:close()

			assert.same({
				{ "CharacterData", "some text\n" },
				{ "Comment", " <a comment> with some & symbols " },
				{ "CharacterData", "\nsome more text" },
			}, cbdata)
		end)


		it("Default handler", function()
			local root = [[<to> hi &xuxu; </to>]]
			local r = ""
			local p = test_parser {
				Default = function(p, data) r = r .. data end,
			}
			assert(p:parse(preamble))
			assert(p:parse(root))
			p:close()

			assert.equal(preamble..root, r)
		end)


		it("DefaultExpand handler", function()
			local root = [[<to> hi &xuxu; </to>]]
			local r = ""
			local p = test_parser {
				DefaultExpand = function(p, data) r = r .. data end,
			}
			assert(p:parse(preamble))
			assert(p:parse(root))
			p:close()

			assert.equal((preamble..root):gsub("&xuxu;", "is this a xuxu?"), r)
		end)


		it("handles notation declarations and unparsed entities", function()
			local p = test_parser { "UnparsedEntityDecl", "NotationDecl" }
			p:setbase("/base")
			assert(p:parse(preamble))
			assert(p:parse[[<hihi explanation="test-unparsed"/>]])
			p:close()

			assert.same({
				{ "NotationDecl", "TXT", "/base", "txt" },
				{ "UnparsedEntityDecl", "test-unparsed", "/base", "unparsed.txt", nil, "txt" },
			}, cbdata)
		end)


		it("handles entity declarations", function()
			local p = test_parser { "EntityDecl" }
			p:setbase("/base")
			assert(p:parse(preamble))
			assert(p:parse[[<hihi explanation="test-unparsed"/>]])
			p:close()

			assert.same({
				{ "EntityDecl", "xuxu", false, "is this a xuxu?", "/base" },
				{ "EntityDecl", "test-entity", false, nil, "/base", "entity1.xml" },
				{ "EntityDecl", "test-unparsed", false, nil, "/base", "unparsed.txt", nil, "txt" },
				{ "EntityDecl", "myParameterEntity", true, "myElement | myElement2 | myElement3", "/base" },
				{ "EntityDecl", "emptyValue", true, "", "/base" },
			}, cbdata)
		end)


		it("handles attribute list declarations", function()
			local p = test_parser { "AttlistDecl" }
			p:setbase("/base")
			assert(p:parse(preamble))
			assert(p:parse[[<hihi explanation="test-unparsed"/>]])
			p:close()

			assert.same({
				{ "AttlistDecl", "to", "method", "CDATA", "POST", true },
				{ "AttlistDecl", "hihi", "explanation", "ENTITY", nil, true },
			}, cbdata)
		end)


		it("handles attribute list declarations; multiple attributes", function()
			local p = test_parser { "AttlistDecl" }
			p:setbase("/base")
			assert(p:parse(d[[
				<?xml version="1.0" standalone="yes"?>
				<!DOCTYPE lab_group [
					<!ELEMENT student_name (#PCDATA)>
					<!ATTLIST student_name student_no ID #REQUIRED>
					<!ATTLIST student_name tutor_1 IDREF #IMPLIED>
					<!ATTLIST student_name tutor_2 IDREF #IMPLIED>
				]>
				<root/>
			]]))
			p:close()

			assert.same({
				{ "AttlistDecl", "student_name", "student_no", "ID", nil, true },
				{ "AttlistDecl", "student_name", "tutor_1", "IDREF", nil, false },
				{ "AttlistDecl", "student_name", "tutor_2", "IDREF", nil, false },
			}, cbdata)
		end)


		it("handles attribute list declarations with namespaces", function()
			local p = test_parser({
				"AttlistDecl",
				"StartNamespaceDecl", "EndNamespaceDecl",
				"StartElement", "EndElement"
			}, "?")
			p:setbase("/base")
			assert(p:parse(d[[
				<?xml version="1.0" ?>
				<!DOCTYPE kbs:myRoot [
				 <!ELEMENT kbs:myRoot (kbs:child1, kbs:child2+) >
				 <!ATTLIST kbs:myRoot
					xmlns:kbs CDATA #FIXED "http://www.example.com/">
				 <!ELEMENT kbs:child1 (#PCDATA) >
				 <!ELEMENT kbs:child2 (#PCDATA) >
				]>
				<kbs:myRoot>
				 <kbs:child1>valid</kbs:child1>
				 <kbs:child2>doc</kbs:child2>
				</kbs:myRoot>
			]])) -- example from: https://www.informit.com/articles/article.aspx?p=31837&seqNum=6
			p:close()

			assert.same({
				{ 'AttlistDecl', 'kbs:myRoot', 'xmlns:kbs', 'CDATA', 'http://www.example.com/', true },
				{ 'StartNamespaceDecl', 'kbs', 'http://www.example.com/' },
				{ 'StartElement', 'http://www.example.com/?myRoot', {} },
				{ 'StartElement', 'http://www.example.com/?child1', {} },
				{ 'EndElement', 'http://www.example.com/?child1' },
				{ 'StartElement', 'http://www.example.com/?child2', {} },
				{ 'EndElement', 'http://www.example.com/?child2' },
				{ 'EndElement', 'http://www.example.com/?myRoot' },
				{ 'EndNamespaceDecl', 'kbs' },
			}, cbdata)
		end)


		it("handles namespace declarations", function()
			local p = test_parser({
				"StartNamespaceDecl", "EndNamespaceDecl",
				"StartElement", "EndElement"
			}, "?")

			assert(p:parse(d[[
				<root>
					<x xmlns:space='a/namespace'>
						defined namespace on x
						<space:a attr1="1" space:attr2="2">named namespace for a</space:a>
					</x>
					<y xmlns='b/namespace'>
						default namespace on y
						<b>inherited namespace for b</b>
					</y>
				</root>
			]]))
			p:close()

			assert.same({
				{ "StartElement", "root", {} },
				{ "StartNamespaceDecl", "space", "a/namespace" },
				{ "StartElement", "x", {} },
				{ "StartElement", "a/namespace?a", {
					"attr1", "a/namespace?attr2",
					["attr1"] = "1",
					["a/namespace?attr2"] = "2",
				} },
				{ "EndElement", "a/namespace?a" },
				{ "EndElement", "x" },
				{ "EndNamespaceDecl", "space" },
				{ "StartNamespaceDecl", nil, "b/namespace" },
				{ "StartElement", "b/namespace?y", {} },
				{ "StartElement", "b/namespace?b", {} },
				{ "EndElement", "b/namespace?b" },
				{ "EndElement", "b/namespace?y" },
				{ "EndNamespaceDecl", nil },
				{ "EndElement", "root" },
			}, cbdata)
		end)


		it("handles namespace triplet", function()
			local p = test_parser({
					"StartNamespaceDecl", "EndNamespaceDecl",
					"StartElement", "EndElement"
				}, "?")

			assert(p:returnnstriplet(true):parse(d[[
				<root>
					<x xmlns:space='a/namespace'>
						defined namespace on x
						<space:a attr1="1" space:attr2="2">named namespace for a</space:a>
					</x>
					<y xmlns='b/namespace'>
						default namespace on y
						<b>inherited namespace for b</b>
					</y>
				</root>
			]]))
			p:close()

			assert.same({
				{ "StartElement", "root", {} },
				{ "StartNamespaceDecl", "space", "a/namespace" },
				{ "StartElement", "x", {} },
				{ "StartElement", "a/namespace?a?space", {
					"attr1", "a/namespace?attr2?space",
					["attr1"] = "1",
					["a/namespace?attr2?space"] = "2",
				} },
				{ "EndElement", "a/namespace?a?space" },
				{ "EndElement", "x" },
				{ "EndNamespaceDecl", "space" },
				{ "StartNamespaceDecl", nil, "b/namespace" },
				{ "StartElement", "b/namespace?y", {} },
				{ "StartElement", "b/namespace?b", {} },
				{ "EndElement", "b/namespace?b" },
				{ "EndElement", "b/namespace?y" },
				{ "EndNamespaceDecl", nil },
				{ "EndElement", "root" },
			}, cbdata)
		end)


		it("handles doctype declarations", function()
			local p = test_parser { "StartDoctypeDecl"}
			assert(p:parse([[<!DOCTYPE root PUBLIC "foo" "hello-world">]]))
			assert(p:parse[[<root/>]])
			p:close()

			assert.same({
				{ "StartDoctypeDecl", "root", "hello-world", "foo", false },
			}, cbdata)
		end)


		it("skipped entity handler", function()
			local p = test_parser {
				"Default",
				"SkippedEntity", "CharacterData",
				"StartElement", "EndElement",
			}
			-- skip default handler during preamble
			local cb = p:getcallbacks().Default
			p:getcallbacks().Default = function() end
			assert(p:parse(preamble))
			p:getcallbacks().Default = cb
			assert(p:parse[[<root attr1="attr: &xuxu;">body start: &xuxu; :body end</root>]])
			p:close()

			assert.same({
				{ 'StartElement', 'root', {
					 'attr1',
					 attr1 = 'attr: is this a xuxu?',  -- expanded
				} },
				{ 'CharacterData', 'body start: ' },
				{ 'SkippedEntity', 'xuxu', false },    -- reported
				{ 'CharacterData', ' :body end' },
				{ 'EndElement', 'root' },
			}, cbdata)
		end)


		it("handles ExternalEntity", function()
			local entities = { ["entity1.xml"] = "<hi/>" }
			local p = test_parser {
				"StartElement", "EndElement",
				ExternalEntityRef = function (p, context, base, systemID, publicId)
					assert.equal("/base", base)
					return context:parse(entities[systemID])
				end
			}

			p:setbase("/base")
			assert(p:parse(preamble))
			assert(p:parse(d[[
				<to> &test-entity;
				</to>
			]]))
			assert(p:getbase() == "/base")
			p:close()

			assert.same({
				{ "StartElement", "to", { method = "POST" } },
				{ "StartElement", "hi", {} },
				{ "EndElement", "hi" },
				{ "EndElement", "to" },
			}, cbdata)
		end)



		describe("Element Declarations", function()

			-- test data from examples on this page:
			-- https://xmlwriter.net/xml_guide/element_declaration.shtml
			local data = {
				{
					desc = "PCDATA",
					xml = [[
						<!DOCTYPE foo [
							<!ELEMENT bar (#PCDATA)>
						]>
						<root/>
					]],
					expected = {
						{ "ElementDecl", "bar", "MIXED" },
					},
				}, {
					desc = "EMPTY",
					xml = [[
						<!DOCTYPE foo [
							<!ELEMENT bar EMPTY>
						]>
						<root/>
					]],
					expected = {
						{ "ElementDecl", "bar", "EMPTY" },
					},
				}, {
					desc = "ANY",
					xml = [[
						<!DOCTYPE foo [
							<!ELEMENT bar ANY>
						]>
						<root/>
					]],
					expected = {
						{ "ElementDecl", "bar", "ANY" },
					},
				}, {
					desc = "children",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student (id)>
							<!ELEMENT id (#PCDATA)>
						]>
						<student>
							<id>9216735</id>
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "SEQUENCE", nil, {
							{
								name = "id",
								type = "NAME",
							}
						} },
						{ "ElementDecl", "id", "MIXED" },
					},
				}, {
					desc = "sequence of children",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student (id,surname,firstname)>
							<!ELEMENT id (#PCDATA)>
							<!ELEMENT firstname (#PCDATA)>
							<!ELEMENT surname (#PCDATA)>
						]>
						<student>
							<id>9216735</id>
							<surname>Smith</surname>
							<firstname>Jo</firstname>
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "SEQUENCE", nil, {
							{
								name = "id",
								type = "NAME",
							},
							{
								name = "surname",
								type = "NAME",
							},
							{
								name = "firstname",
								type = "NAME",
							},
						} },
						{ "ElementDecl", "id", "MIXED" },
						{ "ElementDecl", "firstname", "MIXED" },
						{ "ElementDecl", "surname", "MIXED" },
					},
				}, {
					desc = "children with qualifiers",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student (dob?,subject*,dummy+)>
							<!ELEMENT dob (#PCDATA)>
							<!ELEMENT subject (#PCDATA)>
							<!ELEMENT dummy (#PCDATA)>
						]>
						<student>
							<dob>19.06.74</dob>
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "SEQUENCE", nil, {
							{
								name = "dob",
								quantifier = "?",
								type = "NAME",
							},
							{
								name = "subject",
								quantifier = "*",
								type = "NAME",
							},
							{
								name = "dummy",
								quantifier = "+",
								type = "NAME",
							},
						} },
						{ "ElementDecl", "dob", "MIXED" },
						{ "ElementDecl", "subject", "MIXED" },
						{ "ElementDecl", "dummy", "MIXED" },
					},
				}, {
					desc = "choice of children",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student (id|surname)>
							<!ELEMENT id (#PCDATA)>
						]>
						<student>
								<id>9216735</id>
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "CHOICE", nil, {
							{
								name = "id",
								type = "NAME",
							},
							{
								name = "surname",
								type = "NAME",
							},
						} },
						{ "ElementDecl", "id", "MIXED" },
					},
				}, {
					desc = "nested children 1",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student (surname,firstname*,dob?,(origin|sex)?)>
							<!ELEMENT surname (#PCDATA)>
							<!ELEMENT firstname (#PCDATA)>
							<!ELEMENT sex (#PCDATA)>
						]>
						<student>
							<surname>Smith</surname>
							<firstname>Jo</firstname>
							<firstname>Sephine</firstname>
							<sex>female</sex>
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "SEQUENCE", nil, {
							{
								name = "surname",
								type = "NAME",
							},
							{
								name = "firstname",
								quantifier = "*",
								type = "NAME",
							},
							{
								name = "dob",
								quantifier = "?",
								type = "NAME",
							},
							{
								quantifier = "?",
								type = "CHOICE",
								children = {
									{
										name = "origin",
										type = "NAME",
									},
									{
										name = "sex",
										type = "NAME",
									},
								}
							},
						} },
						{ "ElementDecl", "surname", "MIXED" },
						{ "ElementDecl", "firstname", "MIXED" },
						{ "ElementDecl", "sex", "MIXED" },
					},
				}, {
					desc = "nested children 2",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student (surname,firstname)>
							<!ELEMENT firstname (fullname,nickname)>
							<!ELEMENT surname (#PCDATA)>
							<!ELEMENT fullname (#PCDATA)>
							<!ELEMENT nickname (#PCDATA)>
						]>
						<student>
							<surname>Smith</surname>
							<firstname>
								<fullname>Josephine</fullname>
								<nickname>Jo</nickname>
							</firstname>
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "SEQUENCE", nil, {
							{
								name = "surname",
								type = "NAME",
							},
							{
								name = "firstname",
								type = "NAME",
							},
						} },
						{ "ElementDecl", "firstname", "SEQUENCE", nil, {
							{
								name = "fullname",
								type = "NAME",
							},
							{
								name = "nickname",
								type = "NAME",
							}
						} },
						{ "ElementDecl", "surname", "MIXED" },
						{ "ElementDecl", "fullname", "MIXED" },
						{ "ElementDecl", "nickname", "MIXED" },
					},
				}, {
					desc = "nested children 3",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student (sex|maritalstatus*)>
						]>
						<student>
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "CHOICE", nil, {
							{
								name = "sex",
								type = "NAME",
							},
							{
								name = "maritalstatus",
								quantifier = "*",
								type = "NAME",
							},
						} },
					},
				}, {
					desc = "nested children 4",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student ((sex,maritalstatus)*)>
						]>
						<student>
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "SEQUENCE", nil, {
							{
								quantifier = "*",
								type = "SEQUENCE",
								children = {
									{
										name = "sex",
										type = "NAME",
									},
									{
										name = "maritalstatus",
										type = "NAME",
									},
								},
							},
						} },
					},
				}, {
					desc = "mixed content 1",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student (#PCDATA|id)*>
							<!ELEMENT id (#PCDATA)>
						]>
						<student>
							Here's a bit of text mixed up with the child element.
							<id>9216735</id>
							You can put text anywhere, before or after the child element.
							You don't even have to include the 'id' element.
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "MIXED", "*", {
							{
								name = "id",
								type = "NAME",
							},
						} },
						{ "ElementDecl", "id", "MIXED" },
					},
				}, {
					desc = "mixed content 2",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student (#PCDATA)>
						]>
						<student>
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "MIXED" },
					},
				}, {
					desc = "mixed content 3",
					xml = [[
						<!DOCTYPE student [
							<!ELEMENT student (#PCDATA|id|surname|dob)*>
							<!ELEMENT id (#PCDATA)>
							<!ELEMENT surname (#PCDATA)>
						]>
						<student>
							You can put text anywhere. You can also put the elements in any
							order in the document.
							<surname>Smith</surname>
							And, you don't have to include all the elements listed in the
							element declaration.
							<id>9216735</id>
						</student>
					]],
					expected = {
						{ "ElementDecl", "student", "MIXED", "*", {
							{
								name = "id",
								type = "NAME",
							}, {
								name = "surname",
								type = "NAME",
							}, {
								name = "dob",
								type = "NAME",
							}
						} },
						{ "ElementDecl", "id", "MIXED" },
						{ "ElementDecl", "surname", "MIXED" },
					},
				}
			}

			for i, case in ipairs(data) do
				it(case.desc, function()
					assert:set_parameter("TableFormatLevel", -1) -- display full table depth
					local p = test_parser { "ElementDecl" }
					assert(p:parse(d(case.xml)))
					p:close()
					assert.same(case.expected, cbdata)
				end)
			end

		end)



		describe("error handling", function()

			it("bad xml", function()
				local p = test_parser {}
				local status, msg, line, col, byte = p:parse(d[[
					<tag>
					  <other< </other>
					</tag>]]
				)

				assert.same({
					status = nil,
					msg = "not well-formed (invalid token)",
					line = 2,
					col = 9,
					byte = 15,
				},{
					status = status,
					msg = msg,
					line = line,
					col = col,
					byte = byte,
				})
			end)


			it("incomplete doc (early finish)", function()
				local p = test_parser {}
				assert(p:parse("<to>"))
				local status, msg, line, col, byte = p:parse()

				assert.same({
					status = nil,
					msg = "no element found",
					line = 1,
					col = 5,
					byte = 5,
				},{
					status = status,
					msg = msg,
					line = line,
					col = col,
					byte = byte,
				})
			end)


			it("invalid sequences; parse after finish", function()
				local p = test_parser {}
				assert(p:parse[[<to></to>]])
				assert(p:parse())
				local r = { p:parse(" ") }
				assert.same({nil, "cannot parse - document is finished" }, r)
			end)


			it("closing unfinshed doc", function()
				local p = test_parser {}
				assert(p:parse[[<to>]])
				assert.has.error(function()
					p:close()
				end, "error closing parser: no element found")
			end)


			it("calling parser:stop() to abort", function()
				local stopped
				local p = test_parser {
					StartElement = function (parser, name, attr)
						if name == "stop" then
							parser:stop()
							stopped = true
						else
							stopped = false
						end
					end,
				}

				local r = { p:parse[[
					<root>
						<parseme>Hello</parseme>
						<stop>here</stop>
						<notparsed/>
					</root>]] }

				assert.is_true(stopped)
				assert.same({
					nil,
					"parsing aborted",
					3,  -- line
					13, -- column
					56, -- position
				}, r)
			end)

		end)


		it("position reporting", function()
			local pos
			local p = test_parser {
				ProcessingInstruction = function(p)
					pos = { p:pos() }
				end,
			}

			assert(p:parse(d[[
				<to> <?test where is `pos'? ?>
				</to>]]
			))
			p:close()

			assert.same({
				1, -- line
				6, -- column
				6, -- position
			}, pos)
		end)

	end)



	describe("garbage collection", function()

		local gcinfo = function() return collectgarbage"count" end


		it("normal", function()
			for i=1,100000 do
				-- due to a small bug in Lua...
				if (math.mod or math.fmod)(i, 100) == 0 then collectgarbage() end
				lxp.new {}
			end
			collectgarbage()
			collectgarbage()
			local x = gcinfo()
			for i=1,100000 do
				-- due to a small bug in Lua...
				if (math.mod or math.fmod)(i, 100) == 0 then collectgarbage() end
				lxp.new {}
			end
			collectgarbage()
			collectgarbage()
			assert(math.abs(gcinfo() - x) <= 2)
		end)


		it("circular references", function()
			collectgarbage()
			collectgarbage()
			for i=1,100000 do
				-- due to a small bug in Lua...
				if (math.mod or math.fmod)(i, 100) == 0 then collectgarbage() end
				local p, x	-- luacheck: ignore
				p = lxp.new {
					StartElement = function()
						x = tostring(p)
					end
				}
			end
			collectgarbage()
			collectgarbage()
			local x = gcinfo()
			for i=1,100000 do
				-- due to a small bug in Lua...
				if (math.mod or math.fmod)(i, 100) == 0 then collectgarbage() end
				local p, x	-- luacheck: ignore
				p = lxp.new {
					StartElement = function()
						x = tostring(p)
					end
				}
			end
			collectgarbage()
			collectgarbage()
			assert(math.abs(gcinfo() - x) <= 2)
		end)

	end)

end)
