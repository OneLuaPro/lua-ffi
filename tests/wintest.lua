--
-- Minimalist lua-ffi examples and testing for MSVC builds
--
local ffi = require "ffi"
local lfs = require "lfs"

-- Declaration of utilized C-functions
-- https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/crt-alphabetical-function-reference
-- std lib functions
ffi.cdef([[
   void srand(unsigned int seed);
   int rand(void);
   size_t strlen(const char *str);
   char *_strtime(char *timestr);
   time_t time(time_t *destTime);
]])
-- National Instruments DAQmx fubnctions (ffi.cdef may be called not just one time)
ffi.cdef([[
   int32_t DAQmxGetSysNIDAQMajorVersion(uint32_t *data);
   int32_t DAQmxGetSysNIDAQMinorVersion(uint32_t *data);
   int32_t DAQmxGetSysNIDAQUpdateVersion(uint32_t *data);
]])

-- https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/rand
print("Print 10 random numbers by calling rand() from C StdLib ...")
print("   C-declaration: void srand(unsigned int seed);")
print("   C-declaration: int rand(void);")
for i=1, 10 do
   if i == 1 then
      print("   Setting random seed to 12345.")
      ffi.C.srand(12345)
   end
   io.write(string.format("   %d",ffi.C.rand()))
end
print("\nDone.\n")

-- https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/strlen-wcslen-mbslen-mbslen-l-mbstrlen-mbstrlen-l
print("Testing a call to strlen() ...")
print("   C-declaration: size_t strlen(const char *str);")
local teststr = "The quick brown fox jumps over the lazy dog."
print(string.format("   The test string is '%s'",teststr))
print(string.format("   Lua: #teststr = %d",#teststr))
print(string.format("   C: strlen(..) = %d",ffi.C.strlen(teststr)))
print("Done.\n")

-- https://github.com/q66/cffi-lua/blob/master/tests/cast.lua
print("Testing strings are convertible to char pointers ...")
local foo = "hello world"
local foop = ffi.cast("const char *", foo)
if ffi.string(foop) == "hello world" then
   print("   PASSED")
else
   print("   FAILED")
end
print("Done.\n")


print("Copy Lua string to C-string using ffi.copy() ...")
-- create random printable ASCII Lua string of length strlen
local strlen <const> = 4096
local strtab = {}
for _=1, strlen do
   strtab[#strtab+1] = string.char(math.random(32,126))
end
teststr = table.concat(strtab)
-- print(string.format("   teststr = %s",teststr))
-- create cstring
local cstr = ffi.new("char[]",strlen+1)	-- Extra space for '\0'
-- copy
local cnt = ffi.copy(cstr,teststr)
-- print(string.format("   C-str      = %s",ffi.string(cstr)))
print(string.format("   Chars cp'd = %d",cnt))
if ffi.string(cstr) == teststr then
   print("   PASSED string comparison")
else
   print("   FAILED string comparison")
end
print("Done.\n")


-- https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/strtime-wstrtime
print("Testing char[] passing to _strtime() ...")
print("   C-declaration: char *_strtime(char *timestr);")
local buf=ffi.new("char[]",9)
print(string.format("   Current time is %s",ffi.string(ffi.C._strtime(buf))))
print("Done.\n")

-- https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/time-time32-time64
print("Testing seconds elapsed since midnight (00:00:00), January 1, 1970 ...")
print("   C-declaration: time_t time(time_t *destTime);")
print(string.format("   Using function return value : %d",ffi.C.time(ffi.nullptr)))
local t = ffi.new("time_t")
ffi.C.time(ffi.addressof(t))
print(string.format("   Using destTime argument     : %d",ffi.tonumber(t)))
print("Done.\n")

-- 1D-Array-Test
print("Testing uint8_t 1D-array ...")
local arrSize = 1024*1024*4
local arr=ffi.new("uint8_t[]",arrSize)
print(string.format("   Created array size is %f MB.",ffi.sizeof(arr)/1024/1024))
local compare = {}
for i=0, arrSize-1 do
   local rnd=math.random(0,255)	-- full uint8_t range
   compare[i] = rnd
   arr[i] = rnd
end
local result = true
for i=0, arrSize-1 do
   -- compare
   result = result and (compare[i] == arr[i])
end
if result then
   print("   PASSED array content comparison")
else
   print("   FAILED array content comparison")
end
print("Done.\n")


-- DLL load and usage
local dllfile <const> = "C:/Windows/System32/nicaiu.dll"
print(string.format("Testing NIDAQmx DLL access using %s ...",dllfile))
if lfs.attributes(dllfile) == nil then
   -- DLL not installed
   print("   DLL not installed, test skipped.")
else
   print("   C-declaration: int32_t DAQmxGetSysNIDAQMajorVersion(uint32_t *data);")
   print("   C-declaration: int32_t DAQmxGetSysNIDAQMinorVersion(uint32_t *data);")
   print("   C-declaration: int32_t DAQmxGetSysNIDAQUpdateVersion(uint32_t *data);")
   local dll = ffi.load(dllfile)
   local arg = ffi.new("uint32_t")
   dll.DAQmxGetSysNIDAQMajorVersion(ffi.addressof(arg))
   print(string.format("   DAQmxGetSysNIDAQMajorVersion  = %d",ffi.tonumber(arg)))
   dll.DAQmxGetSysNIDAQMinorVersion(ffi.addressof(arg))
   print(string.format("   DAQmxGetSysNIDAQMinorVersion  = %d",ffi.tonumber(arg)))
   dll.DAQmxGetSysNIDAQUpdateVersion(ffi.addressof(arg))
   print(string.format("   DAQmxGetSysNIDAQUpdateVersion = %d",ffi.tonumber(arg)))
end
print("Done.\n")
