package = "LuaExpat"
version = "1.3.3-1"
source = {
   url = "https://github.com/tomasguisasola/luaexpat/archive/v1.3.3.tar.gz",
   md5 = "",
   dir = "luaexpat-1.3.3",
}
description = {
   summary = "XML Expat parsing",
   detailed = [[
      LuaExpat is a SAX (Simple API for XML) XML parser based on the
      Expat library.
   ]],
   license = "MIT/X11",
   homepage = "http://www.keplerproject.org/luaexpat/",
}
dependencies = {
   "lua >= 5.0"
}
external_dependencies = {
   EXPAT = {
      header = "expat.h"
   }
}
build = {
   type = "builtin",
   modules = {
    lxp = { 
      sources = { "src/lxplib.c" },
      libraries = { "expat" },
      incdirs = { "$(EXPAT_INCDIR)", "src/" },
      libdirs = { "$(EXPAT_LIBDIR)" },
    },
    ["lxp.lom"] = "src/lxp/lom.lua",
    ["lxp.totable"] = "src/lxp/totable.lua",
   },
   copy_directories = { "doc", "tests" }
}
