# lua-ffi

**lua-ffi** is a portable and lightweight C Foreign Function Interface (FFI) extension for Lua. Based on libffi, it allows Lua scripts to call C functions and use C data types directly without the need to compile C wrapper code. It aims for high compatibility with the LuaJIT FFI syntax.

## Features

- **Portable:** Compatible with Lua 5.x
- **Lightweight:** Written in pure C with a small footprint
- **Dynamic:** Declare C interfaces directly within Lua using `ffi.cdef`

## Supported C Data Types

The integrated lexer recognizes a wide range of standard and system types natively. These can be used in declarations and memory allocations without additional setup.

| Category             | Supported Elements / Types                                   |
| -------------------- | ------------------------------------------------------------ |
| Standard Base Types  | `void`, `bool`, `char`, `short`, `int`, `long`, `float`, `double` |
| Fixed-width Integers | `int8_t`, `int16_t`, `int32_t`, `int64_t`, `uint8_t`, `uint16_t`, `uint32_t`, `uint64_t` |
| Qualifiers           | `const`, `signed`, `unsigned`                                |
| Filesystem (POSIX)   | `ino_t`, `dev_t`, `mode_t`, `off_t`, `nlink_t`, `blksize_t`, `blkcnt_t` |
| Process & Identity   | `pid_t`, `uid_t`, `gid_t`                                    |
| Memory & Time        | `size_t`, `ssize_t`, `time_t`, `useconds_t`, `suseconds_t`   |
| Complex Syntax       | Pointers (`*`), Arrays (`[ ]`), `struct`, `union`, `typedef`, variadic functions (`...`) |

## Example

This example demonstrates how to declare system functions, define structures, and allocate memory for C types.

```lua
local ffi = require 'ffi'
local path = require 'pl.path'

local is_windows = path.is_windows

if is_windows then
    ffi.cdef([[
        typedef struct {
            uint32_t dwLowDateTime;
            uint32_t dwHighDateTime;
        } FILETIME;

        void GetSystemTimeAsFileTime(FILETIME *lpSystemTimeAsFileTime);
        char *strerror(int errnum);
    ]])
else
    ffi.cdef([[
        struct timeval {
            time_t      tv_sec;
            suseconds_t tv_usec;
        };
        int gettimeofday(struct timeval *tv, void *tz);
        char *strerror(int errnum);
    ]])
end

if is_windows then
    local ft = ffi.new('FILETIME')
    ffi.C.GetSystemTimeAsFileTime(ft)

    -- Convert cdata values to standard Lua numbers immediately.
    -- This avoids "arithmetic on a cdata value" errors.
    local h = tonumber(ft.dwHighDateTime)
    local l = tonumber(ft.dwLowDateTime)

    -- Calculation: (High << 32) + Low
    local ull = (h * 4294967296) + l

    -- Convert to Unix Epoch (100-nanosecond intervals since 1601 to seconds since 1970)
    local unix_sec = math.floor(ull / 10000000 - 11644473600)
    local unix_usec = math.floor((ull / 10) % 1000000)

    print('Windows System Time:')
    print('Seconds:', unix_sec, 'Microseconds:', unix_usec)
else
    local tv = ffi.new('struct timeval')
    if ffi.C.gettimeofday(tv, nil) < 0 then
        -- ffi.errno() is also useful for error checking
        print('Error calling gettimeofday')
    else
        print('POSIX System Time:')
        print('Seconds:', tonumber(tv.tv_sec), 'Microseconds:', tonumber(tv.tv_usec))
    end
end
```

## Lua FFI Integration Guide

This guide defines the standards for interfacing with external C functions and system APIs using the **Foreign Function Interface (FFI)**.

### Declaration of C Structures and Functions

Before an external function can be invoked, its signature must be declared via `ffi.cdef`.

- **Platform Guards:** Use conditional logic to load platform-specific header definitions.
- **Data Types:** Use explicit bit-width types (e.g., `uint32_t`, `int64_t`) to ensure consistent memory layout across different architectures.

```lua
local ffi = require('ffi')

-- Defining structures and function prototypes
if is_windows then
    ffi.cdef[[
        typedef struct {
            uint32_t dwLowDateTime;
            uint32_t dwHighDateTime;
        } FILETIME;
        void GetSystemTimeAsFileTime(FILETIME *lpSystemTimeAsFileTime);
    ]]
else
    ffi.cdef[[
        struct timeval {
            long tv_sec;
            long tv_usec;
        };
        int gettimeofday(struct timeval *tv, void *tz);
    ]]
end
```

### Memory Allocation (`ffi.new`)

Objects are created using `ffi.new`. These objects are managed by the automatic garbage collector.

- **Syntax:** Use `ffi.new("type")` for single structures or `ffi.new("type[n]")` for arrays.
- **Initialization:** Memory is zero-initialized by default.

### Converting C Data to Lua Types

Converting `cdata` (C data types) into native Lua numbers is essential to prevent "arithmetic on a cdata value" errors during calculations.

- **Explicit Casting:** Use `tonumber()` to cast simple numeric types into Lua numbers.
- **64-bit Calculations:** When combining two 32-bit values (High/Low) into a single timestamp, use the formula `(high * 4294967296) + low`. This keeps the value within the precision limits of standard Lua doubles.

### Error Handling

FFI calls do not trigger native Lua errors automatically. Return values must be checked manually.

- **System Errors:** Include `char *strerror(int errnum);` in your definitions to convert system error codes into human-readable strings.
- **Validation:** Check return codes (e.g., values `< 0`) immediately following the function call.

### Best Practices

- **Static Scope:** Call `ffi.cdef` once at the module level. Avoid re-defining signatures inside loops or functions.
- **Performance:** Direct field access (e.g., `struct.member`) is highly optimized and should be preferred over complex abstraction layers.

## Acknowledgements

This project was inspired by and takes concepts from the following repositories:

- [cffi-lua](https://github.com/q66/cffi-lua)
- [LuaJIT FFI](https://luajit.org/ext_ffi.html)

Special thanks to the authors for their excellent work in the Lua ecosystem.

## License

See `https://github.com/OneLuaPro/lua-ffi/blob/main/LICENSE`.