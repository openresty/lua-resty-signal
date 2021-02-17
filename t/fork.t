use lib '.';
use t::TestSignal::signal 'no_plan';

master_process_enabled(1);

add_block_preprocessor(sub {
    my $block = shift;

    my $http_config = $block->http_config || '';
    my $init_by_lua_block = $block->init_by_lua_block || '';

    $http_config .= <<_EOC_;
    lua_package_path "./lib/?.lua;;";
    lua_package_cpath "./?.so;;";

    lua_shared_dict shd_fork 1m;

    init_by_lua_block {
        local process = require "ngx.process"
        local ok, err = process.enable_privileged_agent()
        if not ok then
            ngx.log(ngx.ERR, "enable_privileged_agent failed: ", err)
        end
    }

    init_worker_by_lua_block {
        local typ = (require "ngx.process").type
        local resty_signal = require "resty.signal"
        local fork = resty_signal.fork
        local wait = resty_signal.wait
        local waitpid = resty_signal.waitpid
        local sigset = resty_signal.sigset
        local sigemptyset = resty_signal.sigemptyset
        local sigaddset = resty_signal.sigaddset
        local sigdelset = resty_signal.sigdelset
        local sigmaskhow = resty_signal.sigmaskhow
        local sigprocmask = resty_signal.sigprocmask
        local signal = resty_signal.signal
        local g_pid
        local shd_fork = ngx.shared.shd_fork

        local function call_back(sig_num)
            ngx.log(ngx.INFO, "call_back, sig_num:", sig_num)
        end

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
            USR1 = 10,
            SEGV = 11,
            USR2 = 12,
            PIPE = 13,
            ALRM = 14,
            TERM = 15,
            CHLD = 17,
            CONT = 18,
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
            PWR = 30
        }

        local v = typ()
        if v == "privileged agent" then
            local new_sigset = sigset()
            local old_sigset = sigset()
            sigemptyset(new_sigset)
            sigemptyset(old_sigset)
            sigaddset(new_sigset, "CHLD")
            sigprocmask("UNBLOCK", new_sigset, old_sigset)
            ngx.log(ngx.WARN, "process type: ", v)

            for sig, _ in pairs(signals) do
                --ngx.log(ngx.INFO, "signal:" .. sig)
                signal(sig, call_back)
            end

            shd_fork:set("privileged_proc_pid", ngx.worker.pid())
            g_pid = fork()
            if g_pid == 0 then
                -- child proc
                ngx.log(ngx.INFO, "child proc:", g_pid)
                shd_fork:set("forked_proc_key", "forked_proc_val")
                os.exit(0)
            else
                ngx.log(ngx.INFO, "master proc:", g_pid)
            end
        end
    }
_EOC_

    $block->set_value("http_config", $http_config);
}); 

run_tests();
 
__DATA__
 
=== TEST 1:
--- request
    GET /t?a=3
--- grep_error_log eval
qr/init_worker_by_lua:\d+: process type: \w+/
--- grep_error_log_out eval
[
qr/init_worker_by_lua:\d+: process type: \w+/,
qr/init_worker_by_lua:\d+: child proc: 0/,
qr/init_worker_by_lua:\d+: master proc: \d+/
]
--- response_body
3
 
 
=== TEST 2:
--- config
    location = /t {
        content_by_lua_block {
            local shd_fork = ngx.shared.shd_fork
            ngx.say(shd_fork:get("forked_proc_key"))
        }
    }
--- request
    GET /t
--- grep_error_log eval
qr/init_worker_by_lua:\d+: process type: \w+/
--- grep_error_log_out eval
[
qr/init_worker_by_lua:\d+: process type: \w+/,
qr/init_worker_by_lua:\d+: child proc: 0/,
qr/init_worker_by_lua:\d+: master proc: \d+/
]
--- response_body
forked_proc_val


=== TEST 3:
--- config
    location = /t {
        content_by_lua_block {
            local resty_signal = require "resty.signal"
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
                USR1 = 10,
                SEGV = 11,
                USR2 = 12,
                PIPE = 13,
                ALRM = 14,
                TERM = 15,
                CHLD = 17,
                CONT = 18,
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
                PWR = 30
            }

            local shd_fork = ngx.shared.shd_fork
            local pid = tonumber(shd_fork:get("privileged_proc_pid"))
            resty_signal.kill(pid, "HUP")
            resty_signal.kill(pid, "INT")
            resty_signal.kill(pid, "QUIT")
            --for sig, _ in pairs(signals) do
            --    resty_signal.kill(pid, sig)
            --    ngx.sleep(0.01)
            --end 
        }
    }
--- request
    GET /t
--- response_body