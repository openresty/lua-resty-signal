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
        local signal = resty_signal.signal

        local function call_back(sig_num)
            ngx.log(ngx.INFO, typ(), " call_back, sig_num:", sig_num)
        end

        local signals = {
            "HUP",
            "INT",
            "QUIT",
            "ILL",
            "TRAP",
            "ABRT",
            "BUS",
            "FPE",
            "USR1",
            "SEGV",
            "USR2",
            "PIPE",
            "ALRM",
            "TERM",
            "CHLD",
            "CONT",
            "TSTP",
            "TTIN",
            "TTOU",
            "URG",
            "XCPU",
            "XFSZ",
            "VTALRM",
            "PROF",
            "WINCH",
            "IO",
            "PWR"
        }

        for _, sig in ipairs(signals) do
            signal(sig, call_back)
        end

        for _, sig in ipairs(signals) do
            resty_signal.kill(ngx.worker.pid(), sig)            
        end
    }
_EOC_

    $block->set_value("http_config", $http_config);
}); 

run_tests();
 
__DATA__


=== TEST 1:
--- config
    location = /t {
        content_by_lua_block {
            ngx.say("xx")
        }
    }
--- request
GET /t
--- grep_error_log eval
qr/init_worker_by_lua:\d+: (privileged agent|worker) call_back, sig_num:\d, \w+/
--- grep_error_log_out eval
qr/init_worker_by_lua:\d+: (privileged agent|worker) call_back, sig_num:\d, \w+/
--- response_body
xx
