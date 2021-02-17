local _M = {
    version = 0.02
}


local ffi = require "ffi"
local base = require "resty.core.base"
local process = require "ngx.process"


local C = ffi.C
local ffi_str = ffi.string
local ffi_new = ffi.new
local tonumber = tonumber
local assert = assert
local errno = ffi.errno
local type = type
local new_tab = base.new_tab
local error = error
local string_format = string.format


local load_shared_lib
do
    local string_gmatch = string.gmatch
    local string_match = string.match
    local io_open = io.open
    local io_close = io.close

    local cpath = package.cpath

    function load_shared_lib(so_name)
        local tried_paths = new_tab(32, 0)
        local i = 1

        for k, _ in string_gmatch(cpath, "[^;]+") do
            local fpath = string_match(k, "(.*/)")
            fpath = fpath .. so_name
            -- Don't get me wrong, the only way to know if a file exist is
            -- trying to open it.
            local f = io_open(fpath)
            if f ~= nil then
                io_close(f)
                return ffi.load(fpath)
            end

            tried_paths[i] = fpath
            i = i + 1
        end

        return nil, tried_paths
    end  -- function
end  -- do


local resty_signal, tried_paths = load_shared_lib("librestysignal.so")
if not resty_signal then
    error("could not load librestysignal.so from the following paths:\n" ..
          table.concat(tried_paths, "\n"), 2)
end


ffi.cdef[[
int resty_signal_signum(int num);
int resty_signal_sigmaskhow(int how);
]]


if not pcall(function () return C.kill end) then
    ffi.cdef("int kill(int32_t pid, int sig);")
end


if not pcall(function () return C.strerror end) then
    ffi.cdef("char *strerror(int errnum);")
end


if not pcall(function() return C.signal end) then
    ffi.cdef [[
        typedef void (*sighandler_t)(int);
        sighandler_t signal(int signum, sighandler_t handler);
    ]]
end


if not pcall(function() return C.sigprocmask end) then
    ffi.cdef [[
        typedef struct {
          unsigned long int __val[16];
        } __sigset_t;
        typedef __sigset_t sigset_t;
        int sigemptyset(sigset_t *set);
        int sigfillset(sigset_t *set);
        int sigaddset(sigset_t *set, int signum);
        int sigdelset(sigset_t *set, int signum);
        int sigismember(const sigset_t *set, int signum);
        int sigprocmask(int how, const sigset_t *set,
               sigset_t *oset);
    ]]
end


if not pcall(function() return C.fork end) then
    ffi.cdef [[
        int fork(void);
    ]]
end


if not pcall(function() return C.waitpid end) then
    ffi.cdef [[
        int waitpid(int pid, int *wstatus, int options);
    ]]
end


if not pcall(function() return C.wait end) then
    ffi.cdef [[
        int wait(int *wstatus);
    ]]
end

-- Below is just the ID numbers for each POSIX signal. We map these signal IDs
-- to system-specific signal numbers on the C land (via librestysignal.so).
local signals = {
    NONE = 0,
    HUP = 1,
    INT = 2,
    QUIT = 3,
    ILL = 4,
    TRAP = 5,
    ABRT = 6,
    BUS = 7,
    FPE = 8,
    KILL = 9,
    USR1 = 10,
    SEGV = 11,
    USR2 = 12,
    PIPE = 13,
    ALRM = 14,
    TERM = 15,
    CHLD = 17,
    CONT = 18,
    STOP = 19,
    TSTP = 20,
    TTIN = 21,
    TTOU = 22,
    URG = 23,
    XCPU = 24,
    XFSZ = 25,
    VTALRM = 26,
    PROF = 27,
    WINCH = 28,
    IO = 29,
    PWR = 30,
    EMT = 31,
    SYS = 32,
    INFO = 33
}


local hows = {
    BLOCK = 1,
    UNBLOCK = 2,
    SETMASK = 3
}


local function signum(name)
    local sig_num
    if type(name) == "number" then
        sig_num = name
    else
        local id = signals[name]
        if not id then
            return nil, "unknown signal name"
        end

        sig_num = tonumber(resty_signal.resty_signal_signum(id))
        if sig_num < 0 then
            error(
                string_format("missing C def for signal %s = %d", name, id),
                2
            )
        end
    end
    return sig_num
end


function _M.kill(pid, sig)
    assert(sig)

    local sig_num, err = signum(sig)
    if err then
        return nil, err
    end

    local rc = tonumber(C.kill(assert(pid), sig_num))
    if rc == 0 then
        return true
    end

    local err = ffi_str(C.strerror(errno()))
    return nil, err
end


local function sigset()
    local sigset = ffi_new("sigset_t[1]")
    return sigset
end
    
    
local function sigemptyset(sigset)
    if not sigset then
        return nil, "sigset is nil"
    end
    
    return C.sigemptyset(sigset)
end


local function sigfillset(sigset)
    if not sigset then
        return nil, "sigset is nil"
    end

    return C.sigfillset(sigset)
end


local function sigaddset(sigset, name)
    if not sigset then
        return nil, "sigset is nil"
    end
    
    
    local sig_num, err = signum(name)
    if err then
        return nil, err
    end

    return C.sigaddset(sigset, sig_num)
end


local function sigdelset(sigset, name)
    if not sigset then
        return nil, "sigset is nil"
    end
    
    local sig_num, err = signum(name)
    if err then
        return nil, err
    end

    return C.sigdelset(sigset, sig_num)
end


local function sigmaskhow(how)
    local sig_how
    if not how then
        return nil, "not how"
    end

    if type(how) == "number" then
        sig_how = how
    else
        local id = hows[how]
        if not id then
            return nil, "unknown sigprocmask name"
        end

        sig_how = tonumber(resty_signal.resty_signal_sigmaskhow(id))
        if sig_how < 0 then
            error(
                string_format("missing C def for sigprocmask %s = %d", how, id),
                2
            )
        end
    end
    return sig_how
end


local function sigprocmask(how, sigset, old_sigset)
    local sig_how, err = sigmaskhow(how)
    if err then
        return nil, err
    end
    
    if not sigset then
        return nil, "sigset is nil"
    end

    return C.sigprocmask(sig_how, sigset, old_sigset)
end


local function signal(name, call_back)
    local sig_num, err = signum(name)
    if err then
        return nil, err
    end
    
    if "function" ~= type(call_back) then
        return nil, "call_back type must be a function"
    end

    local cb = ffi.new(ffi.typeof("sighandler_t"), call_back)
    return C.signal(sig_num, cb)
end


local function fork()
    if "privileged agent" ~= process.type() then
        return nil, "fork function must call by privileged process"
    end

    return C.fork()
end


--[[
    block wait
]]
local function wait()
    local ws = ffi.new("int[1]", 0)
    return C.wait(ws), tonumber(ws[0])
end


--[[
    unblock wait
]]
local function waitpid(pid)
    local ws = ffi.new("int[1]", 0)
    return C.waitpid(pid or -1, ws, 1), tonumber(ws[0])
end

_M.signum = signum
_M.sigset = sigset
_M.sigemptyset = sigemptyset
_M.sigfillset = sigfillset
_M.sigaddset = sigaddset
_M.sigdelset = sigdelset
_M.sigmaskhow = sigmaskhow
_M.sigprocmask = sigprocmask
_M.signal = signal
_M.fork = fork
_M.wait = wait
_M.waitpid = waitpid


return _M
