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

        local v = typ()
        if v == "privileged agent" then
            local new_sigset = sigset()
            local old_sigset = sigset()
            sigemptyset(new_sigset)
            sigemptyset(old_sigset)
            sigaddset(new_sigset, "CHLD")
            sigprocmask("UNBLOCK", new_sigset, old_sigset)
            signal("CHLD", call_back)

            ngx.log(ngx.WARN, "process type: ", v)
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
