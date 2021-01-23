use t::TestSignal::signal 'no_plan';
 
run_tests();
 
__DATA__
 
=== TEST 1:
--- request
    GET /t?a=3
--- response_body
3
 
 
 
=== TEST 2:
--- request
    GET /t?a=blah
--- response_body
blah
