LuaExpat
--------

[![Unix build](https://img.shields.io/github/workflow/status/lunarmodules/luaexpat/Unix%20build?label=Unix%20build&logo=linux)](https://github.com/lunarmodules/luaexpat/actions/workflows/unix_build.yml)
[![Luacheck](https://github.com/lunarmodules/luaexpat/workflows/Luacheck/badge.svg)](https://github.com/lunarmodules/luaexpat/actions/workflows/luacheck.yml)

Overview

LuaExpat is a SAX XML parser based on the Expat library. LuaExpat is free
software and uses the same license as Lua 5.1.

Status

Current version is UNRELEASED. It is designed to work with all versions of
Lua between 5.1 and 5.4. It has been tested on Linux with Expat 2.2.5.

Download

LuaExpat source can be downloaded from its project page.

History

Version 1.4.0 [23/Apr/2021]

        * Improved Lua version support (5.1 - 5.4)
        * Fix memory leak when callbacks reference a parser object
        * Expose Expat library version (lxp._EXPAT_VERSION)

Version 1.3.0 [04/Apr/2014]

        * Lua 5.2 support (thanks Tomás Guisasola Gorham)
        * support for the XmlDecl handler
        * add parser:getcurrentbytecount() (XML_GetCurrentByteCount)
        * ability to disable CharacterData merging
        * Makefile improvements (thanks Vadim Misbakh-Soloviov)

Version 1.2.0 [02/Jun/2011]

        * support for the StartDoctypeDecl handler
        * add parser:stop() to abort parsing inside a callback

Version 1.1.0 [05/Jun/2006]

        * adapted to work on both Lua 5.0 and Lua 5.1
        * updated to Expat 2.0.0

Version 1.0.2 [23/Mar/2006]

        * minor bugfix, lom correct module name is lxp.lom

Version 1.0.1 [06/Jun/2005]

        * minor changes for compatibility with Expat version 1.95.8

Version 1.0 [2/Dec/2004]
Version 1.0 Beta [4/Apr/2004]
Version 1.0 Alpha [10/Dec/2003]

References

LuaExpat uses the Expat library. For details on the C API please refer to the article "Using Expat".
LuaExpat implements the SAX API.

Credits

Version 1.0 was designed by Roberto Ierusalimschy, André Carregal and Tomás Guisasola
as part of the Kepler Project which holds its copyright. The implementation was coded
by Roberto Ierusalimschy, based on a previous design by Jay Carlson.

LuaExpat development was sponsored by Fábrica Digital and FINEP.

Contact

For more information please contact us (info at keplerproject dot org). Comments are welcome!
You can also reach other Kepler developers and users on the Kepler Project mailing list.
