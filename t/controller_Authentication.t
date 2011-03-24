use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Catalyst::Test', 'MediaMogul' }
BEGIN { use_ok 'MediaMogul::Controller::Authentication' }

ok( request('/authentication')->is_success, 'Request should succeed' );
done_testing();
