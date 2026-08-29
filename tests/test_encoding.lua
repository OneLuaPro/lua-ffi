local charset = require("encoding")

print(string.format("Current code page is %s",charset.get_system_codepage()))

-- Setup for Chinese
charset.set_codepage(936)

-- Test string
local s = "你好world"

-- Test
assert(s == charset.SystemMBCS_to_UTF8(charset.UTF8_to_SystemMBCS(s)))
print("Test passed with code page 936.")
