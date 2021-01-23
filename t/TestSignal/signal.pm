package t::TestSignal::signal;
 
use Test::Nginx::Socket -Base;
 
add_block_preprocessor(sub {
    my $block = shift;
 
    if (!defined $block->config) {
        $block->set_value("config", <<'_END_');
            location = /t {
                echo $arg_a;
            }
_END_
    }
});
 
1;