/*
** $Id: lxplib.c,v 1.16 2007/06/05 20:03:12 carregal Exp $
** LuaExpat: Lua bind for Expat library
** See Copyright Notice in license.html
*/


#include <assert.h>
#include <stdlib.h>
#include <string.h>

#include "expat_config.h"
#include "expat.h"
#if (XML_MAJOR_VERSION == 2 && XML_MINOR_VERSION < 4) || (XML_MAJOR_VERSION < 2)
#error Expat 2.4 or newer is required
#endif

#include "lua.h"
#include "lauxlib.h"


#include "lxplib.h"

#if (LUA_VERSION_NUM == 501)
#define lua_getuservalue(L, i) lua_getfenv(L, i)
#define lua_setuservalue(L, i) lua_setfenv(L, i)
#define luaL_setfuncs(L, R, N) luaL_register(L, NULL, R)
#endif

#if !defined(lua_pushliteral)
#define lua_pushliteral(L, s) \
  lua_pushstring(L, "" s, (sizeof(s)/sizeof(char))-1)
#endif


enum XPState {
  XPSpre,  /* parser just initialized */
  XPSok,   /* state while parsing */
  XPSfinished,  /* state after finished parsing */
  XPSerror,
  XPSstring  /* state while reading a string */
};

struct lxp_userdata {
  lua_State *L;
  XML_Parser parser;  /* associated expat parser */
  int errorref;  /* reference to error message if state is XPSerror */
  enum XPState state;
  luaL_Buffer *b;  /* to concatenate sequences of cdata pieces */
  int bufferCharData; /* whether to buffer cdata pieces */
};

typedef struct lxp_userdata lxp_userdata;


static int reporterror (lxp_userdata *xpu) {
  lua_State *L = xpu->L;
  XML_Parser p = xpu->parser;
  lua_pushnil(L);
  lua_pushstring(L, XML_ErrorString(XML_GetErrorCode(p)));
  lua_pushinteger(L, XML_GetCurrentLineNumber(p));
  lua_pushinteger(L, XML_GetCurrentColumnNumber(p) + 1);
  lua_pushinteger(L, XML_GetCurrentByteIndex(p) + 1);
  return 5;
}


static lxp_userdata *createlxp (lua_State *L) {
  lxp_userdata *xpu = (lxp_userdata *)lua_newuserdata(L, sizeof(lxp_userdata));
  xpu->errorref = LUA_REFNIL;
  xpu->parser = NULL;
  xpu->L = NULL;
  xpu->state = XPSpre;
  luaL_getmetatable(L, ParserType);
  lua_setmetatable(L, -2);
  return xpu;
}


static void lxpclose (lua_State *L, lxp_userdata *xpu) {
  luaL_unref(L, LUA_REGISTRYINDEX, xpu->errorref);
  xpu->errorref = LUA_REFNIL;
  if (xpu->parser)
    XML_ParserFree(xpu->parser);
  xpu->parser = NULL;
}




/*
** Auxiliary function to call a Lua handle
*/
static void docall (lxp_userdata *xpu, int nargs, int nres) {
  lua_State *L = xpu->L;
  assert(xpu->state == XPSok);
  if (lua_pcall(L, nargs + 1, nres, 0) != 0) {
    xpu->state = XPSerror;
    xpu->errorref = luaL_ref(L, LUA_REGISTRYINDEX);  /* error message */
  }
}


/*
** Check whether there is pending Cdata, and call its handle if necessary
*/
static void dischargestring (lxp_userdata *xpu) {
  assert(xpu->state == XPSstring);
  xpu->state = XPSok;
  luaL_pushresult(xpu->b);
  docall(xpu, 1, 0);
}


/*
** Check whether there is a Lua handle for a given event: If so,
** put it on the stack (to be called later), and also push `self'
*/
static int getHandle (lxp_userdata *xpu, const char *handle) {
  lua_State *L = xpu->L;
  if (xpu->state == XPSstring) dischargestring(xpu);
  if (xpu->state == XPSerror)
    return 0;  /* some error happened before; skip all handles */
  lua_pushstring(L, handle);
  lua_gettable(L, 3);
  if (lua_toboolean(L, -1) == 0) {
    lua_pop(L, 1);
    return 0;
  }
  if (!lua_isfunction(L, -1)) {
    luaL_error(L, "lxp '%s' callback is not a function", handle);
  }
  lua_pushvalue(L, 1);  /* first argument in every call (self) */
  return 1;
}



/*
** {======================================================
** Handles
** =======================================================
*/


static void f_StartCdata (void *ud) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (getHandle(xpu, StartCdataKey) == 0) return;  /* no handle */
  docall(xpu, 0, 0);
}


static void f_EndCdataKey (void *ud) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (getHandle(xpu, EndCdataKey) == 0) return;  /* no handle */
  docall(xpu, 0, 0);
}


static void f_CharData (void *ud, const char *s, int len) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (xpu->state == XPSok) {
    if (getHandle(xpu, CharDataKey) == 0) return;  /* no handle */
    if(xpu->bufferCharData != 0) {
      xpu->state = XPSstring;
      luaL_buffinit(xpu->L, xpu->b);
    } else {
      lua_pushlstring(xpu->L, s, len);
      docall(xpu, 1, 0);
    }
  }
  if (xpu->state == XPSstring)
    luaL_addlstring(xpu->b, s, len);
}


static void f_Comment (void *ud, const char *data) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (getHandle(xpu, CommentKey) == 0) return;  /* no handle */
  lua_pushstring(xpu->L, data);
  docall(xpu, 1, 0);
}


static void f_Default (void *ud, const char *data, int len) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (getHandle(xpu, DefaultKey) == 0) return;  /* no handle */
  lua_pushlstring(xpu->L, data, len);
  docall(xpu, 1, 0);
}


static void f_DefaultExpand (void *ud, const char *data, int len) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (getHandle(xpu, DefaultExpandKey) == 0) return;  /* no handle */
  lua_pushlstring(xpu->L, data, len);
  docall(xpu, 1, 0);
}


static void f_StartElement (void *ud, const char *name, const char **attrs) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  lua_State *L = xpu->L;
  int lastspec = XML_GetSpecifiedAttributeCount(xpu->parser) / 2;
  int i = 1;
  if (getHandle(xpu, StartElementKey) == 0) return;  /* no handle */
  lua_pushstring(L, name);
  lua_newtable(L);
  while (*attrs) {
    if (i <= lastspec) {
      lua_pushinteger(L, i++);
      lua_pushstring(L, *attrs);
      lua_settable(L, -3);
    }
    lua_pushstring(L, *attrs++);
    lua_pushstring(L, *attrs++);
    lua_settable(L, -3);
  }
  docall(xpu, 2, 0);  /* call function with self, name, and attributes */
}


static void f_EndElement (void *ud, const char *name) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (getHandle(xpu, EndElementKey) == 0) return;  /* no handle */
  lua_pushstring(xpu->L, name);
  docall(xpu, 1, 0);
}


static int f_ExternaEntity (XML_Parser p, const char *context,
                                          const char *base,
                                          const char *systemId,
                                          const char *publicId) {
  lxp_userdata *xpu = (lxp_userdata *)XML_GetUserData(p);
  lua_State *L = xpu->L;
  lxp_userdata *child;
  int status;
  if (getHandle(xpu, ExternalEntityKey) == 0) return 1;  /* no handle */
  child = createlxp(L);
  child->parser = XML_ExternalEntityParserCreate(p, context, NULL);
  if (!child->parser)
    luaL_error(L, "XML_ParserCreate failed");
  lua_getuservalue(L, 1);
  lua_setuservalue(L, -2); /* child uses the same table of its father */
  lua_pushstring(L, base);
  lua_pushstring(L, systemId);
  lua_pushstring(L, publicId);
  docall(xpu, 4, 1);
  status = lua_toboolean(L, -1);
  lua_pop(L, 1);
  lxpclose(L, child);
  return status;
}


static void f_StartNamespaceDecl (void *ud, const char *prefix,
                                            const char *uri) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  lua_State *L = xpu->L;
  if (getHandle(xpu, StartNamespaceDeclKey) == 0) return;  /* no handle */
  lua_pushstring(L, prefix);
  lua_pushstring(L, uri);
  docall(xpu, 2, 0);
}


static void f_EndNamespaceDecl (void *ud, const char *prefix) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (getHandle(xpu, EndNamespaceDeclKey) == 0) return;  /* no handle */
  lua_pushstring(xpu->L, prefix);
  docall(xpu, 1, 0);
}


static void f_NotationDecl (void *ud, const char *notationName,
                                      const char *base,
                                      const char *systemId,
                                      const char *publicId) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  lua_State *L = xpu->L;
  if (getHandle(xpu, NotationDeclKey) == 0) return;  /* no handle */
  lua_pushstring(L, notationName);
  lua_pushstring(L, base);
  lua_pushstring(L, systemId);
  lua_pushstring(L, publicId);
  docall(xpu, 4, 0);
}


static int f_NotStandalone (void *ud) {
  int status;
  lxp_userdata *xpu = (lxp_userdata *)ud;
  lua_State *L = xpu->L;
  if (getHandle(xpu, NotStandaloneKey) == 0) return 1;  /* no handle */
  docall(xpu, 0, 1);
  status = lua_toboolean(L, -1);
  lua_pop(L, 1);
  return status;
}


static void f_ProcessingInstruction (void *ud, const char *target,
                                               const char *data) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  lua_State *L = xpu->L;
  if (getHandle(xpu, ProcessingInstructionKey) == 0) return;  /* no handle */
  lua_pushstring(L, target);
  lua_pushstring(L, data);
  docall(xpu, 2, 0);
}


static void f_UnparsedEntityDecl (void *ud, const char *entityName,
                                            const char *base,
                                            const char *systemId,
                                            const char *publicId,
                                            const char *notationName) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  lua_State *L = xpu->L;
  if (getHandle(xpu, UnparsedEntityDeclKey) == 0) return;  /* no handle */
  lua_pushstring(L, entityName);
  lua_pushstring(L, base);
  lua_pushstring(L, systemId);
  lua_pushstring(L, publicId);
  lua_pushstring(L, notationName);
  docall(xpu, 5, 0);
}

static void f_EntityDecl (void *ud, const char *entityName,
                                    int is_parameter_entity,
                                    const char *value,
                                    int value_length,
                                    const char *base,
                                    const char *systemId,
                                    const char *publicId,
                                    const char *notationName) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  lua_State *L = xpu->L;
  if (getHandle(xpu, EntityDeclKey) == 0) return;  /* no handle */
  lua_pushstring(L, entityName);
  lua_pushboolean(L, is_parameter_entity);
  if (value == NULL) {
    lua_pushnil(L);
  } else {
    lua_pushlstring(L, value, value_length);
  }
  lua_pushstring(L, base);
  lua_pushstring(L, systemId);
  lua_pushstring(L, publicId);
  lua_pushstring(L, notationName);
  docall(xpu, 7, 0);
}

static void PushElementDeclType(lua_State *L, XML_Content *model) {
  switch(model->type) {
    case XML_CTYPE_EMPTY:
      lua_pushliteral(L, "EMPTY");
      return;
    case XML_CTYPE_ANY:
      lua_pushliteral(L, "ANY");
      return;
    case XML_CTYPE_MIXED:
      lua_pushliteral(L, "MIXED");
      return;
    case XML_CTYPE_NAME:
      lua_pushliteral(L, "NAME");
      return;
    case XML_CTYPE_CHOICE:
      lua_pushliteral(L, "CHOICE");
      return;
    case XML_CTYPE_SEQ:
      lua_pushliteral(L, "SEQUENCE");
      return;
    default:
      /* safe guard, should not happen */
      lua_pushliteral(L, "unknown");
      return;
  }
}

static int PushElementDeclQuant(lua_State *L, XML_Content *model) {
  switch(model->quant) {
    case XML_CQUANT_NONE:
      return 0;
    case XML_CQUANT_OPT:
      lua_pushliteral(L, "?");
      return 1;
    case XML_CQUANT_REP:
      lua_pushliteral(L, "*");
      return 1;
    case XML_CQUANT_PLUS:
      lua_pushliteral(L, "+");
      return 1;
    default:
      /* safe guard, should not happen */
      lua_pushliteral(L, "unknown");
      return 1;
  }
}

static void PushElementDeclChildren(lua_State *L, XML_Content *model) {
  lua_checkstack(L, 4);
  int i;
  XML_Content *child;
  for (i = 0; i < model->numchildren; i++) {
    child = model->children+i;
    lua_newtable(L);
    PushElementDeclType(L, child);
    lua_setfield(L, -2, "type");
    if (PushElementDeclQuant(L, child) != 0) {
      lua_setfield(L, -2, "quantifier");
    }
    if (child->name != NULL) {
      lua_pushstring(L, child->name);
      lua_setfield(L, -2, "name");
    }
    if (child->numchildren > 0 ) {
      lua_newtable(L);
      PushElementDeclChildren(L, child);
      lua_setfield(L, -2, "children");
    }

    lua_rawseti(L, -2, i+1);
  }
}

static void f_ElementDecl (void *ud, const char *name, XML_Content *model) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  lua_State *L = xpu->L;
  if (getHandle(xpu, ElementDeclKey) == 0) {   /* no handle */
    XML_FreeContentModel(xpu->parser, model);
    return;
  }
  lua_pushstring(L, name);
  PushElementDeclType(L, model);
  if (PushElementDeclQuant(L, model) == 0) {
    lua_pushnil(L);
  }
  if (model->numchildren == 0) {
    XML_FreeContentModel(xpu->parser, model);
    docall(xpu, 3, 0);
  } else {
    lua_newtable(L);
    PushElementDeclChildren(L, model);
    XML_FreeContentModel(xpu->parser, model);
    docall(xpu, 4, 0);
  }
}

static void f_AttlistDecl (void *ud, const char *elName,
                                     const char *attName,
                                     const char *attType,
                                     const char *dflt,
                                     int isRequired) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  lua_State *L = xpu->L;
  if (getHandle(xpu, AttlistDeclKey) == 0) return;  /* no handle */
  lua_pushstring(L, elName);
  lua_pushstring(L, attName);
  lua_pushstring(L, attType);
  lua_pushstring(L, dflt);
  lua_pushboolean(L, isRequired);
  docall(xpu, 5, 0);
}

static void f_SkippedEntity (void *ud, const char *entityName,
                                       int isParameter) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  lua_State *L = xpu->L;
  if (getHandle(xpu, SkippedEntityKey) == 0) return;  /* no handle */
  lua_pushstring(L, entityName);
  lua_pushboolean(L, isParameter);
  docall(xpu, 2, 0);
}

static void f_StartDoctypeDecl (void *ud, const XML_Char *doctypeName,
                                          const XML_Char *sysid,
                                          const XML_Char *pubid,
                                          int has_internal_subset) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (getHandle(xpu, StartDoctypeDeclKey) == 0) return;  /* no handle */
  lua_pushstring(xpu->L, doctypeName);
  lua_pushstring(xpu->L, sysid);
  lua_pushstring(xpu->L, pubid);
  lua_pushboolean(xpu->L, has_internal_subset);
  docall(xpu, 4, 0);
}

static void f_EndDoctypeDecl (void *ud) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (getHandle(xpu, EndDoctypeDeclKey) == 0) return;  /* no handle */
  docall(xpu, 0, 0);
}

static void f_XmlDecl (void *ud, const XML_Char *version,
                                 const XML_Char *encoding,
                                 int standalone) {
  lxp_userdata *xpu = (lxp_userdata *)ud;
  if (getHandle(xpu, XmlDeclKey) == 0) return;  /* no handle */
  lua_pushstring(xpu->L, version);
  lua_pushstring(xpu->L, encoding);
  if (standalone >= 0) {
    lua_pushboolean(xpu->L, standalone);
    docall(xpu, 3, 0);
  } else {
    docall(xpu, 2, 0);
  }
}
/* }====================================================== */



static int hasfield (lua_State *L, const char *fname) {
  int res;
  lua_pushstring(L, fname);
  lua_gettable(L, 1);
  res = !lua_isnil(L, -1);
  lua_pop(L, 1);
  return res;
}


static void checkcallbacks (lua_State *L) {
  static const char *const validkeys[] = {
    "StartCdataSection", "EndCdataSection", "CharacterData", "Comment",
    "Default", "DefaultExpand", "StartElement", "EndElement",
    "ExternalEntityRef", "StartNamespaceDecl", "EndNamespaceDecl",
    "NotationDecl", "NotStandalone", "ProcessingInstruction",
    "UnparsedEntityDecl", "EntityDecl", "StartDoctypeDecl", "EndDoctypeDecl",
    "XmlDecl", "AttlistDecl", "SkippedEntity", "ElementDecl", NULL};
  if (hasfield(L, "_nonstrict")) return;
  lua_pushnil(L);
  while (lua_next(L, 1)) {
    lua_pop(L, 1);  /* remove value */
#if ! defined (LUA_VERSION_NUM) || LUA_VERSION_NUM < 501
    if (lua_type(L, -1) != LUA_TSTRING ||
        luaL_findstring(lua_tostring(L, -1), validkeys) < 0)
      luaL_error(L, "invalid key `%s' in callback table", lua_tostring(L, -1));
#else
    luaL_checkoption(L, -1, NULL, validkeys);
#endif
  }
}


static int lxp_make_parser (lua_State *L) {
  XML_Parser p;
  int bufferCharData = (lua_type(L, 3) != LUA_TBOOLEAN) || (lua_toboolean(L, 3) != 0);
  char sep = *luaL_optstring(L, 2, "");
  lxp_userdata *xpu = createlxp(L);
  xpu->bufferCharData = bufferCharData;
  p = xpu->parser = (sep == '\0') ? XML_ParserCreate(NULL) :
                                    XML_ParserCreateNS(NULL, sep);
  if (!p)
    luaL_error(L, "XML_ParserCreate failed");
  luaL_checktype(L, 1, LUA_TTABLE);
  checkcallbacks(L);
  lua_pushvalue(L, 1);
  lua_setuservalue(L, -2);
  XML_SetUserData(p, xpu);
  if (hasfield(L, StartCdataKey) || hasfield(L, EndCdataKey))
    XML_SetCdataSectionHandler(p, f_StartCdata, f_EndCdataKey);
  if (hasfield(L, CharDataKey))
    XML_SetCharacterDataHandler(p, f_CharData);
  if (hasfield(L, CommentKey))
    XML_SetCommentHandler(p, f_Comment);
  if (hasfield(L, DefaultKey))
    XML_SetDefaultHandler(p, f_Default);
  if (hasfield(L, DefaultExpandKey))
    XML_SetDefaultHandlerExpand(p, f_DefaultExpand);
  if (hasfield(L, StartElementKey) || hasfield(L, EndElementKey))
    XML_SetElementHandler(p, f_StartElement, f_EndElement);
  if (hasfield(L, ExternalEntityKey))
    XML_SetExternalEntityRefHandler(p, f_ExternaEntity);
  if (hasfield(L, StartNamespaceDeclKey) || hasfield(L, EndNamespaceDeclKey))
    XML_SetNamespaceDeclHandler(p, f_StartNamespaceDecl, f_EndNamespaceDecl);
  if (hasfield(L, NotationDeclKey))
    XML_SetNotationDeclHandler(p, f_NotationDecl);
  if (hasfield(L, NotStandaloneKey))
    XML_SetNotStandaloneHandler(p, f_NotStandalone);
  if (hasfield(L, ProcessingInstructionKey))
    XML_SetProcessingInstructionHandler(p, f_ProcessingInstruction);
  if (hasfield(L, UnparsedEntityDeclKey))
    XML_SetUnparsedEntityDeclHandler(p, f_UnparsedEntityDecl);
  if (hasfield(L, EntityDeclKey))
    XML_SetEntityDeclHandler(p, f_EntityDecl);
  if (hasfield(L, AttlistDeclKey))
    XML_SetAttlistDeclHandler(p, f_AttlistDecl);
  if (hasfield(L, SkippedEntityKey))
    XML_SetSkippedEntityHandler(p, f_SkippedEntity);
  if (hasfield(L, StartDoctypeDeclKey))
    XML_SetStartDoctypeDeclHandler(p, f_StartDoctypeDecl);
  if (hasfield(L, EndDoctypeDeclKey))
    XML_SetEndDoctypeDeclHandler(p, f_EndDoctypeDecl);
  if (hasfield(L, XmlDeclKey))
    XML_SetXmlDeclHandler(p, f_XmlDecl);
  if (hasfield(L, ElementDeclKey))
    XML_SetElementDeclHandler(p, f_ElementDecl);
  return 1;
}


static lxp_userdata *checkparser (lua_State *L, int idx) {
  lxp_userdata *xpu = (lxp_userdata *)luaL_checkudata(L, idx, ParserType);
  luaL_argcheck(L, xpu, idx, "expat parser expected");
  luaL_argcheck(L, xpu->parser, idx, "parser is closed");
  return xpu;
}


static int parser_gc (lua_State *L) {
  lxp_userdata *xpu = (lxp_userdata *)luaL_checkudata(L, 1, ParserType);
  luaL_argcheck(L, xpu, 1, "expat parser expected");
  lxpclose(L, xpu);
  return 0;
}


static int setbase (lua_State *L) {
  lxp_userdata *xpu = checkparser(L, 1);
  if (XML_SetBase(xpu->parser, luaL_checkstring(L, 2)) == 0)
    luaL_error(L, "no memory to store base");
  lua_settop(L, 1);
  return 1;
}


static int getbase (lua_State *L) {
  lxp_userdata *xpu = checkparser(L, 1);
  lua_pushstring(L, XML_GetBase(xpu->parser));
  return 1;
}


static int getcallbacks (lua_State *L) {
  checkparser(L, 1);
  lua_getuservalue(L, 1);
  return 1;
}


static int parse_aux (lua_State *L, lxp_userdata *xpu, const char *s,
                      size_t len) {
  luaL_Buffer b;
  int status;
  xpu->L = L;
  xpu->state = XPSok;
  xpu->b = &b;
  lua_settop(L, 2);
  getcallbacks(L);
  status = XML_Parse(xpu->parser, s, (int)len, s == NULL);
  if (xpu->state == XPSstring) dischargestring(xpu);
  if (xpu->state == XPSerror) {  /* callback error? */
    lua_rawgeti(L, LUA_REGISTRYINDEX, xpu->errorref);  /* get original msg. */
    lua_error(L);
  }
  if (s == NULL) xpu->state = XPSfinished;
  if (status) {
    lua_settop(L, 1);  /* return parser userdata on success */
    return 1;
  }
  else { /* error */
    return reporterror(xpu);
  }
}


static int lxp_parse (lua_State *L) {
  lxp_userdata *xpu = checkparser(L, 1);
  size_t len;
  const char *s = luaL_optlstring(L, 2, NULL, &len);
  if (xpu->state == XPSfinished) {
    if (s != NULL) {
      lua_pushnil(L);
      lua_pushliteral(L, "cannot parse - document is finished");
      return 2;
    } else {
      lua_settop(L, 1);
      return 1;
    }
  }
  return parse_aux(L, xpu, s, len);
}


static int lxp_close (lua_State *L) {
  int status = 1;
  lxp_userdata *xpu = (lxp_userdata *)luaL_checkudata(L, 1, ParserType);
  luaL_argcheck(L, xpu, 1, "expat parser expected");
  if (xpu->state != XPSfinished)
    status = parse_aux(L, xpu, NULL, 0);
  lxpclose(L, xpu);
  if (status > 1) luaL_error(L, "error closing parser: %s",
                                lua_tostring(L, -status+1));
  lua_settop(L, 1);
  return 1;
}


static int lxp_pos (lua_State *L) {
  lxp_userdata *xpu = checkparser(L, 1);
  XML_Parser p = xpu->parser;
  lua_pushinteger(L, XML_GetCurrentLineNumber(p));
  lua_pushinteger(L, XML_GetCurrentColumnNumber(p) + 1);
  lua_pushinteger(L, XML_GetCurrentByteIndex(p) + 1);
  return 3;
}


static int lxp_setreturnnstriplet (lua_State *L) {
  lxp_userdata *xpu = checkparser(L, 1);
  luaL_argcheck(L, xpu->state == XPSpre, 1, "invalid parser state");
  XML_SetReturnNSTriplet(xpu->parser, lua_toboolean(L, 2));
  lua_settop(L, 1);
  return 1;
}


static int lxp_setencoding (lua_State *L) {
  lxp_userdata *xpu = checkparser(L, 1);
  const char *encoding = luaL_checkstring(L, 2);
  luaL_argcheck(L, xpu->state == XPSpre, 1, "invalid parser state");
  XML_SetEncoding(xpu->parser, encoding);
  lua_settop(L, 1);
  return 1;
}


static int lxp_stop (lua_State *L) {
  lxp_userdata *xpu = checkparser(L, 1);
  lua_pushboolean(L, XML_StopParser(xpu->parser, XML_FALSE) == XML_STATUS_OK);
  return 1;
}


/* Billion Laughs Attack mitigation from Expat 2.4.0+ */
#ifdef XML_DTD
static int lxp_bla_maximum_amplification (lua_State *L) {
  lxp_userdata *xpu = checkparser(L, 1);
  if (! XML_SetBillionLaughsAttackProtectionMaximumAmplification(xpu->parser, luaL_checknumber(L, 2))) {
    lua_pushnil(L);
    lua_pushliteral(L, "failed to set BLA maximum amplification");
    return 2;
  }
  lua_settop(L, 1);
  return 1;
}


static int lxp_bla_activation_threshold (lua_State *L) {
  lxp_userdata *xpu = checkparser(L, 1);
  if (! XML_SetBillionLaughsAttackProtectionActivationThreshold(xpu->parser, luaL_checkinteger(L, 2))) {
    lua_pushnil(L);
    lua_pushliteral(L, "failed to set BLA activation threshold");
    return 2;
  }
  lua_settop(L, 1);
  return 1;
}
#endif


#if !defined LUA_VERSION_NUM
/* Lua 5.0 */
#define luaL_Reg luaL_reg
#endif

static int lxp_getcurrentbytecount (lua_State* L) {
  lxp_userdata *xpu = checkparser(L, 1);
  lua_pushinteger(L, XML_GetCurrentByteCount(xpu->parser));
  return 1;
}

static const struct luaL_Reg lxp_meths[] = {
  {"parse", lxp_parse},
  {"close", lxp_close},
  {"__gc", parser_gc},
  {"pos", lxp_pos},
  {"getcurrentbytecount", lxp_getcurrentbytecount},
  {"setencoding", lxp_setencoding},
  {"getcallbacks", getcallbacks},
  {"getbase", getbase},
  {"setbase", setbase},
  {"returnnstriplet", lxp_setreturnnstriplet},
  {"stop", lxp_stop},
#ifdef XML_DTD
  {"setblamaxamplification", lxp_bla_maximum_amplification},
  {"setblathreshold", lxp_bla_activation_threshold},
#endif
  {NULL, NULL}
};

static const struct luaL_Reg lxp_funcs[] = {
  {"new", lxp_make_parser},
  {NULL, NULL}
};


/*
** Assumes the table is on top of the stack.
*/
static void set_info (lua_State *L) {
  lua_pushliteral (L, "_COPYRIGHT");
  lua_pushliteral (L, LuaExpatCopyright);
  lua_settable (L, -3);
  lua_pushliteral (L, "_DESCRIPTION");
  lua_pushliteral (L, "LuaExpat is a SAX XML parser based on the Expat library");
  lua_settable (L, -3);
  lua_pushliteral (L, "_VERSION");
  lua_pushliteral (L, LuaExpatVersion);
  lua_settable (L, -3);
  lua_pushliteral (L, "_EXPAT_VERSION");
  lua_pushstring (L, XML_ExpatVersion());
  lua_settable (L, -3);
  /* create feature list */
  lua_pushliteral (L, "_EXPAT_FEATURES");
  lua_newtable (L);

  const XML_Feature *features;
  for (features = XML_GetFeatureList (); features->name != NULL; features++) {
    lua_pushstring (L, features->name);
    lua_pushinteger (L, features->value);
    lua_settable (L, -3);
  }
  lua_settable (L, -3);
}

int luaopen_lxp (lua_State *L) {
  luaL_newmetatable(L, ParserType);

  lua_pushliteral(L, "__index");
  lua_pushvalue(L, -2);
  lua_rawset(L, -3);

  luaL_setfuncs (L, lxp_meths, 0);
  lua_pop (L, 1); /* remove metatable */

  lua_newtable (L); /* push library table */
  luaL_setfuncs (L, lxp_funcs, 0);
  set_info (L);
  return 1;
}
