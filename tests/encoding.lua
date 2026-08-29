-------------------------------------------------------------------------------
-- encoding.lua
--
-- A lua-ffi based module for converting strings between UTF-8 and
-- Windows Multi-Byte Character Sets (MBCS/ANSI).
--
-- This module provides a high-performance bridge to the Windows API
-- (kernel32.dll) to handle system-specific encodings like CP1252 (Western),
-- CP936 (Chinese), etc., ensuring proper round-trip conversion.
--
-- Supported environment: Windows
-- Requirements: lua-ffi (https://github.com/OneLuaPro/lua-ffi)
-------------------------------------------------------------------------------
local ffi = require("ffi")

-- Load kernel32 library, which hosts all four below mentioned functions
local ok, kernel32 = pcall(ffi.load, "kernel32")
if not ok then
   error("Whoops, could not load kernel32.dll...")
end

-- Define function interfaces. Notice that present lua-ffi version does not
-- support wchar_t. However, it is fully valif to use uint16_t instead.
ffi.cdef[[
   uint32_t GetACP(void);
   int IsValidCodePage(unsigned int CodePage);
   int MultiByteToWideChar(unsigned int cp, unsigned long flg,
                           const char* str, int cb, uint16_t* wstr, int cch);
   int WideCharToMultiByte(unsigned int cp, unsigned long flg, const uint16_t* wstr,
                           int cch, char* str, int cb, const char* def, int* used);
]]

local M = {}

-- Windows Constants
local CP_ACP <const> = 0     -- Default ANSI Code Page
local CP_UTF8 <const> = 65001 -- UTF-8 Code Page

-- Default target codepage (System ANSI)
local current_cp = CP_ACP

--- Sets the target codepage for MBCS conversions.
-- @param cp can be "system" (CP_ACP) or a specific Windows Codepage ID (e.g., 1252, 936).
function M.set_codepage(cp)
   if cp == "system" then
      current_cp = CP_ACP
   elseif type(cp) == "number" then
      if kernel32.IsValidCodePage(cp) == 0 then
	 error(string.format("Unsupported or invalid Codepage ID: %d", cp))
      end
      current_cp = cp
   else
      error("Invalid codepage. Use 'system' or a numeric ID.")
   end
end

--- Internal helper to convert strings using Windows API
local function win_convert(str, from_cp, to_cp)
   if not str or str == "" then return str end

   -- Phase 1: Convert source to UTF-16 (WideChar, same as uint16_t buffer)
   local wlen = kernel32.MultiByteToWideChar(from_cp, 0, str, -1, nil, 0)
   if wlen == 0 then return nil end
   local wbuf = ffi.new("uint16_t[?]", wlen)
   kernel32.MultiByteToWideChar(from_cp, 0, str, -1, wbuf, wlen)

   -- Phase 2: Convert UTF-16 to target encoding
   local tlen = kernel32.WideCharToMultiByte(to_cp, 0, ffi.cast("const uint16_t*", wbuf),
					  -1, nil, 0, nil, nil)
   if tlen == 0 then return nil end
   local tbuf = ffi.new("char[?]", tlen)
   kernel32.WideCharToMultiByte(to_cp, 0, ffi.cast("const uint16_t*", wbuf),
			     -1, tbuf, tlen, nil, nil)

   return ffi.string(tbuf, tlen - 1)
end

--- Converts a System/MBCS string to UTF-8
function M.SystemMBCS_to_UTF8(s)
   return win_convert(s, current_cp, CP_UTF8)
end

--- Converts a UTF-8 string to System/MBCS
function M.UTF8_to_SystemMBCS(s)
   return win_convert(s, CP_UTF8, current_cp)
end

--- Returns the current system ANSI code page ID.
-- @return numeric ID (e.g., 1252 for Western Europe)
function M.get_system_codepage()
    return kernel32.GetACP()
end

return M
