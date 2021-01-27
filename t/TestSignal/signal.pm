package t::TestSignal::signal;
 
use Test::Nginx::Socket -Base;
 
add_block_preprocessor(sub {
    my $block = shift;
 
    if (!defined $block->config) {
        $block->set_value("config", <<'_END_');
            location = /t {
                content_by_lua_block {
                    ngx.say(ngx.var.arg_a)
                }
            }
_END_
    }
});
 
1;