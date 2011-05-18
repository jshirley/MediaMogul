use File::Spec;
use FindBin;
use Test::More;

use HTTP::Request;
use Test::WWW::Mechanize::Catalyst;

use Imager;

use_ok('MediaMogul::User');

my $user = MediaMogul::User->new(
    username => 'test',
    password => 'test user',
    permissions => {
        '@admin' => 1
    }
);
isa_ok($user, 'MediaMogul::User', 'created user');
ok($user->store, 'stored user');

my $name = 'test_profile_' . time;

my $mech = Test::WWW::Mechanize::Catalyst->new( catalyst_app => 'MediaMogul' );
$mech->default_header('Content-type' => 'application/json' );

$mech->post_ok(
    "/login",
    {
        username => 'test',
        password => 'test user'
    },
    'logged in'
);

$mech->post_ok(
    "/admin/profile",
    {
        name        => $name,
        media_type  => 'image',
        action      => 'root',
        'arguments.0.key'   => 'scale',
        'arguments.0.value' => 'ypixels:250,xpixels:250,type:min',
        'arguments.1.key'   => 'rotate',
        'arguments.1.value' => 'degrees:45',
    },
);

$mech->get_ok("/admin/profile/$name", 'fetched stored profile');

$mech->get_ok("/media");
my $resp = $mech->post(
    "/media",
    [
        'asset.name' => 'override-key',
        file => [ File::Spec->catfile($FindBin::Bin, "data", "test2.png") ],
    ],
    'Content_Type' => 'form-data'
);
$mech->get_ok('/media/override-key/embed', 'embed page ok');
$mech->content_contains(
    q{media/override-key/display"},
    'proper embedding');

$mech->get_ok("/media/override-key/embed?profile=$name", 'embed page ok');
diag($mech->content);
$mech->content_contains(
    q{media/override-key/image/transform?rotate=degrees%3A45&scale=ypixels%3A250%2Cxpixels%3A250%2Ctype%3Amin" alt="override-key" title="override-key">},
    'proper embedding with profile');
$mech->get_ok('/media/override-key/display', 'fetch image out ok');
cmp_ok(length($mech->content), '==', 156, 'file length ok on display');

$mech->get_ok("/media/override-key/image/transform?rotate=degrees%3A45&scale=ypixels%3A250%2Cxpixels%3A250%2Ctype%3Amin");
cmp_ok(length($mech->content), '==', 1110, 'file length ok on transform');

my $uri = URI->new('/media/override-key', 'http');
   $uri = $mech->base ? URI->new_abs( $uri, $mech->base ) : URI->new( $uri );

$resp = $mech->request( HTTP::Request->new( DELETE => $uri ) );
ok($resp->is_success, 'delete key ok');


$uri = URI->new("/admin/profile/$name", 'http');
   $uri = $mech->base ? URI->new_abs( $uri, $mech->base ) : URI->new( $uri );
$resp = $mech->request( HTTP::Request->new( DELETE => $uri ) );
ok($resp->is_success, 'delete key ok');

$resp = $mech->get("/admin/profile/$name");
ok(!$resp->is_success, "profile fetch fails");
is($resp->status_line, '404 Not Found', 'not found');

done_testing;
