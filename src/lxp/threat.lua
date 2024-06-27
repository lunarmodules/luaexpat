--- Expat Parser wrapper which protects against XML threats.
--[[ inspired by;

- https://docs.sensedia.com/en/api-platform-guide/4.2.x.x/interceptors/security_xml-threat-protection.html
- https://tech.forums.softwareag.com/t/xml-threat-protection/236959
- https://docs.mulesoft.com/api-manager/2.x/apply-configure-xml-threat-task
- https://github.com/Trust1Team/kong-plugin-xml-threat-protection

]]


local lxp = require "lxp"


local threat = {}

local defaults = {
	depth = 50,				-- depth of tags
	allowDTD = true,		-- is a DTD allowed

	-- counts
	maxChildren = 100,		-- max number of children (DOM2;  Element, Text, Comment,
							-- ProcessingInstruction, CDATASection). NOTE: adjacent text/CDATA
							-- sections are counted as 1 (so text-cdata-text-cdata is 1 child).
	maxAttributes = 100,	-- max number of attributes (including default ones), if not parsing
							-- namespaces, then the namespaces will be counted as attributes.
	maxNamespaces = 20,		-- max number of namespaces defined on a tag

	-- size limits
	document = 10*1024*1024,	-- 10 mb; size of entire document in bytes
	buffer = 1024*1024,			-- 1 mb; size of the unparsed buffer
	comment = 1024,				-- 1 kb; size of comment in bytes
	localName = 1024,			-- 1 kb; size of localname (or full name if not parsing namespaces) in bytes,
								-- applies to tags and attributes
	prefix = 1024,				-- 1 kb; size of prefix in bytes (only if parsing namespaces), applies to
								-- tags and attributes
	namespaceUri = 1024,		-- 1 kb; size of namespace uri in bytes (only if parsing namespaces)
	attribute = 1024*1024,		-- 1 mb; size of attribute value in bytes
	text = 1024*1024,			-- 1 mb; text inside tags (counted over all adjacent text/CDATA)
	PITarget = 1024,			-- 1 kb; size of processing instruction target in bytes
	PIData = 1024,				-- 1 kb; size of processing instruction data in bytes
	entityName = 1024,			-- 1 kb; size of entity name in EntityDecl in bytes
	entity = 1024,				-- 1 kb; size of entity value in EntityDecl in bytes
	entityProperty = 1024,		-- 1 kb; size of systemId, publicId, or notationName in EntityDecl in bytes
}



--- Creates a parser that implements xml threat protection.
function threat.new(callbacks, separator, merge_character_data)
	assert(type(callbacks) == "table", "expected arg #1 to be a table with callbacks")
	local checks = callbacks.threat
	assert(type(checks) == "table", "expected entry 'threat' in callbacks table to be a table with checks")
	if checks.maxNamespaces or checks.prefix or checks.namespaceUri then
		assert(separator ~= nil, "expected separator to be set when checking maxNamespaces, prefix, and/or namespaceUri")
	end

	-- apply defaults
	for setting, value in pairs(defaults) do
		if checks[setting] == nil then
			checks[setting] = value
		end
	end
	if separator == nil then
		checks.maxNamespaces = nil
		checks.prefix = nil
		checks.namespaceUri = nil
	end

	do -- add missing callbacks so we get all checks
		local callbacks_def = {
			"CharacterData",
			"Comment",
			--"Default",
			--"DefaultExpand",
			"EndCdataSection",
			"EndDoctypeDecl",
			"EndElement",
			"EndNamespaceDecl",
			"ExternalEntityRef",
			"NotStandalone",
			"NotationDecl",
			"ProcessingInstruction",
			"StartCdataSection",
			"StartDoctypeDecl",
			"StartElement",
			"StartNamespaceDecl",
			--"UnparsedEntityDecl", -- superseded by EntityDecl
			"EntityDecl",
			"AttlistDecl",
			"ElementDecl",
			"SkippedEntity",
			"XmlDecl",
		}
		local nop = function() end
		for _, cbname in ipairs(callbacks_def) do
			if not callbacks[cbname] then
				callbacks[cbname] = nop
			end
		end
	end

	local parser -- the standard expat parser; forward declaration
	local p = {} -- the parser object to return
	local new_cbs = {} -- new callbacks
	local threat_error_data -- error data to return

	local function threat_error(msg)
		threat_error_data = { msg, parser:pos() } -- total 4 results
		parser:stop()
	end

	function p:close()
		local ok, err = parser:close()
		return ok == parser and p or ok, err
	end
	function p:getbase() return parser:getbase() end
	function p:getcallbacks() return callbacks end
	function p:pos() return parser:pos() end
	function p:getcurrentbytecount() return parser:getcurrentbytecount() end
	function p:setbase(base)
		local ok, err = parser:setbase(base)
		return ok == parser and p or ok, err
	end
	function p:setblamaxamplification(amp)
		local ok, err = parser:setblamaxamplification(amp)
		return ok == parser and p or ok, err
	end
	function p:setblathreshold(threshold)
		local ok, err = parser:setblathreshold(threshold)
		return ok == parser and p or ok, err
	end
	function p:setencoding(encoding)
		local ok, err = parser:setencoding(encoding)
		return ok == parser and p or ok, err
	end
	function p:stop()
		local ok, err = parser:stop()
		return ok == parser and p or ok, err
	end
	function p:returnnstriplet(enable)
		local ok, err = parser:returnnstriplet(enable)
		return ok == parser and p or ok, err
	end
	do
		local size = 0
		function p:parse(s)
			size = size + #(s or "")
			if checks.document and size > checks.document then
				return nil, "document too large"
			end

			local a,b,c,d,e = parser:parse(s)
			if threat_error_data then
				return nil, threat_error_data[1], threat_error_data[2], threat_error_data[3], threat_error_data[4]
			end
			if checks.buffer then
				local _, _, pos = parser:pos()
				if size - pos > checks.buffer then
					return nil, "unparsed buffer too large"
				end
			end
			if a == parser then
				return p,b,c,d,e
			end
			return a,b,c,d,e
		end
	end

	-- stats to track
	local context = {			-- current context
		children = 0,
	}
	local stack = { context }	-- tracking depth of context

	for key, cb in pairs(callbacks) do
		local ncb

		if key == "CharacterData" then
			ncb = function(parser, data)
				local l = context.charcount
				if not l then
					l = #data
					if checks.maxChildren then
						context.children = context.children + 1
						if context.children > checks.maxChildren then
							return threat_error("too many children")
						end
					end
				else
					l = l + #data
				end
				if checks.text and l > checks.text then
					return threat_error("text/CDATA node(s) too long")
				end
				context.charcount = l
				return callbacks.CharacterData(p, data)
			end

		elseif key == "Comment" then
			ncb = function(parser, data)
				if checks.comment and #data > checks.comment then
					return threat_error("comment too long")
				end

				context.children = context.children + 1
				if checks.maxChildren and context.children > checks.maxChildren then
					return threat_error("too many children")
				end

				context.charcount = nil -- reset text-length counter

				return callbacks.Comment(p, data)
			end

		elseif key == "Default" then
			ncb = function(parser, data)
				return callbacks.Default(p, data)
			end

		elseif key == "DefaultExpand" then
			ncb = function(parser, data)
				return callbacks.DefaultExpand(p, data)
			end

		elseif key == "EndCdataSection" then
			ncb = function(parser)
				return callbacks.EndCdataSection(p)
			end

		elseif key == "EndElement" then
			ncb = function(parser, elementName)
				local d = #stack
				context = stack[d-1]	-- revert to previous level context
				stack[d] = nil		-- delete last context
				return callbacks.EndElement(p, elementName)
			end

		elseif key == "EndNamespaceDecl" then
			ncb = function(parser, namespaceName)
				return callbacks.EndNamespaceDecl(p, namespaceName)
			end

		elseif key == "ExternalEntityRef" then  -- TODO: implement
			ncb = function(parser, subparser, base, systemId, publicId)
				-- subparser must be wrapped...
				-- do we need to pass current depth as its initial depth?
				return callbacks.ExternalEntityRef(p, subparser, base, systemId, publicId)
			end

		elseif key == "NotStandalone" then
			ncb = function(parser)
				return callbacks.NotStandalone(p)
			end

		elseif key == "NotationDecl" then  -- TODO: implement
			ncb = function(parser, notationName, base, systemId, publicId)
				return callbacks.NotationDecl(p, notationName, base, systemId, publicId)
			end

		elseif key == "ProcessingInstruction" then
			ncb = function(parser, target, data)
				if checks.PITarget and checks.PITarget < #target then
					return threat_error("processing instruction target too long")
				end

				if checks.PIData and checks.PIData < #data then
					return threat_error("processing instruction data too long")
				end

				context.children = context.children + 1
				if checks.maxChildren and context.children > checks.maxChildren then
					return threat_error("too many children")
				end

				context.charcount = nil -- reset text-length counter

				return callbacks.ProcessingInstruction(p, target, data)
			end

		elseif key == "StartCdataSection" then
			ncb = function(parser)
				return callbacks.StartCdataSection(p)
			end

		elseif key == "StartDoctypeDecl" then  -- TODO: implement
			ncb = function(parser, name, sysid, pubid, has_internal_subset)
				if not checks.allowDTD then
					return threat_error("DTD is not allowed")
				end
				return callbacks.StartDoctypeDecl(p, name, sysid, pubid, has_internal_subset)
			end

		elseif key == "StartElement" then
			ncb = function(parser, elementName, attributes)
				context.children = context.children + 1
				if checks.maxChildren and context.children > checks.maxChildren then
					return threat_error("too many children")
				end

				context.charcount = nil -- reset text-length counter

				context = { children = 0 }
				local d = #stack
				if checks.depth and d > checks.depth then
					return threat_error("structure is too deep")
				end
				d = d + 1
				stack[d] = context

				if separator then
					-- handle namespaces
					local l
					local s,e = elementName:find(separator, 1, true)
					if s then
						l = #elementName - e  -- namespaced
					else
						l = #elementName -- not namespaced, entire key
					end
					if checks.localName and l > checks.localName then
						return threat_error("element localName too long")
					end
				else
					if checks.localName and #elementName > checks.localName then
						return threat_error("element name too long")
					end
				end

				local count = 0
				for key, value in pairs(attributes) do
					if type(key) == "string" then -- we only check the hash entries to prevent doubles
						count = count + 1
						if separator then
							-- handle namespaces
							local l
							local s,e = key:find(separator, 1, true)
							if s then
								l = #key - e  -- namespaced
							else
								l = #key -- not namespaced, entire key
							end
							if checks.localName and l > checks.localName then
								return threat_error("attribute localName too long")
							end
						else
							-- no namespaces
							if checks.localName and #key > checks.localName then
								return threat_error("attribute name too long")
							end
						end
						if checks.attribute and #value > checks.attribute then
							return threat_error("attribute value too long")
						end
					end
				end

				if checks.maxAttributes and count > checks.maxAttributes then
					return threat_error("too many attributes")
				end

				return callbacks.StartElement(p, elementName, attributes)
			end

		elseif key == "StartNamespaceDecl" then
			ncb = function(parser, namespaceName, namespaceUri)
				-- we're storing in the current context, which is one level up
				-- from the tag they are intended for. Because the namespace callbacks
				-- happen before the element callbacks. But for our purposes
				-- this is fine.
				context.ns = (context.ns or 0) + 1
				if checks.maxNamespaces and context.ns > checks.maxNamespaces then
					return threat_error("too many namespaces")
				end

				if checks.prefix and #(namespaceName or "") > checks.prefix then
					return threat_error("prefix too long")
				end

				if checks.namespaceUri and namespaceUri and #namespaceUri > checks.namespaceUri then
					return threat_error("namespaceUri too long")
				end

				return callbacks.StartNamespaceDecl(p, namespaceName, namespaceUri)
			end

		-- elseif key == "UnparsedEntityDecl" then  -- TODO: implement?? superseded by "EntityDecl"
		-- 	ncb = function(parser, entityName, base, systemId, publicId, notationName)
		-- 		return callbacks.UnparsedEntityDecl(p, entityName, base, systemId, publicId, notationName)
		-- 	end

		elseif key == "EndDoctypeDecl" then
			ncb = function(parser)
				return callbacks.EndDoctypeDecl(p)
			end

		elseif key == "XmlDecl" then
			ncb = function(parser, version, encoding, standalone)
				return callbacks.XmlDecl(p, version, encoding, standalone)
			end

		elseif key == "EntityDecl" then
			ncb = function(parser, entityName, is_parameter, value, base, systemId, publicId, notationName)
				if checks.entityName and checks.entityName < #entityName then
					return threat_error("entityName too long")
				end
				if checks.entity and value and checks.entity < #value then
					return threat_error("entity value too long")
				end
				if checks.entityProperty then
					if systemId and checks.entityProperty < #systemId then
						return threat_error("systemId too long")
					end
					if publicId and checks.entityProperty < #publicId then
						return threat_error("publicId too long")
					end
					if notationName and checks.entityProperty < #notationName then
						return threat_error("notationName too long")
					end
				end
				return callbacks.EntityDecl(p, entityName, is_parameter, value, base, systemId, publicId, notationName)
			end

		elseif key == "AttlistDecl" then
			ncb = function(parser, elementName, attrName, attrType, default, required)
				if separator then
					local ePrefix, eName, aPrefix, aName
					if checks.prefix or checks.localName then
						-- namespace based parsing, check against localName+prefix
						local colon = elementName:find(":", 1, true) or 0
						ePrefix = elementName:sub(1, colon-1)
						eName = elementName:sub(colon+1, -1)

						colon = attrName:find(":", 1, true) or 0
						aPrefix = attrName:sub(1, colon-1)
						aName = attrName:sub(colon+1, -1)

						if checks.localName then
							if checks.localName < #eName then
								return threat_error("element localName too long")
							end
							if checks.localName < #aName then
								return threat_error("attribute localName too long")
							end
						end
						if checks.prefix then
							if checks.prefix < #ePrefix then
								return threat_error("element prefix too long")
							end
							if checks.prefix < #aPrefix then
								return threat_error("attribute prefix too long")
							end
						end
					end
				else

					-- no namespace parsing, check against localName
					if checks.localName then
						if checks.localName < #elementName then
							return threat_error("elementName too long")
						end
						if checks.localName < #attrName then
							return threat_error("attributeName too long")
						end
					end
				end

				if default and checks.attribute then
					if checks.attribute < #default then
						return threat_error("attribute default too long")
					end
				end

				return callbacks.AttlistDecl(p, elementName, attrName, attrType, default, required)
			end

		elseif key == "ElementDecl" then
			ncb = function(parser, name, type, quantifier, children)
				if name or children then
					local checkName
					if separator then
						if checks.localName or checks.prefix then
							checkName = function(name)
								local colon = name:find(":", 1, true) or 0
								local ePrefix = name:sub(1, colon-1)
								local eName = name:sub(colon+1, -1)
								if checks.localName and checks.localName < #eName then
									return threat_error("elementDecl localName too long")
								end
								if checks.prefix and checks.prefix < #ePrefix then
									return threat_error("elementDecl prefix too long")
								end
								return true
							end
						end
					elseif checks.localName then
						checkName = function(name)
							if checks.localName < #name then
								return threat_error("elementDecl name too long")
							end
							return true
						end
					end

					if checkName then
						local function checkChild(child)
							if child.name and not checkName(child.name) then
								return
							end
							for _, subchild in ipairs(child.children or {}) do
								if not checkChild(subchild) then
									return
								end
							end
							return true
						end

						if not checkChild { name = name, children = children } then
							return
						end
					end
				end

				return callbacks.ElementDecl(p, name, type, quantifier, children)
			end

		elseif key == "SkippedEntity" then
			ncb = function(parser, name, isParameter)
				return callbacks.SkippedEntity(p, name, isParameter)
			end

		elseif key == "threat" then
			-- threat protection config table, remove, do not pass on
			ncb = nil

		else
			-- unknown entry, just copy
			ncb = cb
		end

		new_cbs[key] = ncb
	end

	-- create final parser with updated/wrapped callbacks
	local err
	parser, err = lxp.new(new_cbs, separator, merge_character_data)
	if not parser then
		return parser, err
	end

	return p
end


return threat
