# vi:ft=

use lib '.';
use t::TestKiller;

plan tests => 3 * blocks();

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: fork kill and signal 
--- config
    location = /t {
        content_by_lua_block {
            local resty_signal = require "resty.signal"
            local ngx_pipe = require "ngx.pipe"
            local kill = resty_signal.kill
            local wait = resty_signal.wait
            local waitpid = resty_signal.waitpid
            local sigset = resty_signal.sigset
            local sigemptyset = resty_signal.sigemptyset
            local sigaddset = resty_signal.sigaddset
            local sigmaskhow = resty_signal.sigmaskhow
            local sigprocmask = resty_signal.sigprocmask
            local signal = resty_signal.signal
            local say = ngx.say

            local g_pid
            local function call_back(sig_num)
                ngx.say("call_back, sig_num:", sig_num)
                local pid, ws = waitpid()
                assert(pid == g_pid)
                return 0
            end

            local sig_set = sigset()
            local old_sigset = sigset()
            sigemptyset(sig_set)
            sigemptyset(old_sigset)
            sigaddset(sig_set, "CHLD")
            sigprocmask("UNBLOCK", sig_set, old_sigset)
            signal("CHLD", call_back)

            -- fork a proc
            local proc = assert(ngx_pipe.spawn("sleep 1s;echo ok"))
            g_pid = proc:pid()
            ngx.sleep(2)
        }
    }
--- response_body_like
call_back, sig_num:\d+
