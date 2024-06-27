/*
** See Copyright Notice in license.html
*/

#define LuaExpatCopyright	"Copyright (C) 2003-2007 The Kepler Project, 2013-2024 Matthew Wild"
#define LuaExpatVersion		"LuaExpat 1.5.2"
#define ParserType		"Expat"

#define StartCdataKey			"StartCdataSection"
#define EndCdataKey			"EndCdataSection"
#define CharDataKey			"CharacterData"
#define CommentKey			"Comment"
#define DefaultKey			"Default"
#define DefaultExpandKey		"DefaultExpand"
#define StartElementKey			"StartElement"
#define EndElementKey			"EndElement"
#define ExternalEntityKey		"ExternalEntityRef"
#define StartNamespaceDeclKey		"StartNamespaceDecl"
#define EndNamespaceDeclKey		"EndNamespaceDecl"
#define NotationDeclKey			"NotationDecl"
#define NotStandaloneKey		"NotStandalone"
#define ProcessingInstructionKey	"ProcessingInstruction"
#define UnparsedEntityDeclKey		"UnparsedEntityDecl"
#define EntityDeclKey			"EntityDecl"
#define AttlistDeclKey			"AttlistDecl"
#define SkippedEntityKey		"SkippedEntity"
#define StartDoctypeDeclKey		"StartDoctypeDecl"
#define EndDoctypeDeclKey		"EndDoctypeDecl"
#define XmlDeclKey			"XmlDecl"
#define ElementDeclKey			"ElementDecl"

int luaopen_lxp (lua_State *L);
