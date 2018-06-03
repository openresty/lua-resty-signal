# vi:ft=

use lib '.';
use t::TestKiller;

plan tests => 3 * blocks();

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: signals whose values are specified by POSIX
--- config
    location = /t {
        content_by_lua_block {
            local resty_signal = require "resty.signal"
            local say = ngx.say
            local signum = resty_signal.signum

            for i, signame in ipairs{ "ABRT", "ALRM", "HUP", "INT", "KILL",
                                      "QUIT", "TERM", "TRAP", "BLAH" } do
                say(signame, ": ", tostring(signum(signame)))
            end

        }
    }
--- response_body
ABRT: 6
ALRM: 14
HUP: 1
INT: 2
KILL: 9
QUIT: 3
TERM: 15
TRAP: 5
BLAH: nil
