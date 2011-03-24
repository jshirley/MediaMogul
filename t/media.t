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

my $mech = Test::WWW::Mechanize::Catalyst->new( catalyst_app => 'MediaMogul' );
$mech->default_header('Content-type' => 'application/json' );

$mech->get_ok("/media");
my $resp = $mech->post(
    "/media",
    [
        name => 'override-key',
        file => [ File::Spec->catfile($FindBin::Bin, "data", "test.txt") ],
    ],
    'Content_Type' => 'form-data'
);

ok(!$resp->is_success, 'unable to upload');
is($resp->status_line, '403 Forbidden', 'access denied');

$mech->post_ok(
    "/login",
    {
        username => 'test',
        password => 'test user'
    },
    'logged in'
);

$mech->get_ok("/media");
my $resp = $mech->post(
    "/media",
    [
        name => 'override-key',
        file => [ File::Spec->catfile($FindBin::Bin, "data", "test.png") ],
    ],
    'Content_Type' => 'form-data'
);

ok($resp->is_success, 'able to upload now');

$mech->get_ok("/media/override-key", 'got media');

$mech->get_ok('/media/override-key/embed', 'embed page ok');
$mech->content_contains(
    q{<img src="http://media.shirley.im/media/override-key/display"},
    'proper embedding');

$mech->get_ok('/media/override-key/display', 'fetch image out ok');
cmp_ok(length($mech->content), '==', 127, 'file length ok on display');

my $uri = URI->new('/media/override-key', 'http');
   $uri = $mech->base ? URI->new_abs( $uri, $mech->base ) : URI->new( $uri );

$resp = $mech->request( HTTP::Request->new( DELETE => $uri ) );
ok($resp->is_success, 'delete key ok');

$resp = $mech->get("/media/override-key");
ok(!$resp->is_success, "media doesn't exist");
is($resp->status_line, '404 Not Found', 'not found');

$mech->get_ok("/media");
my $resp = $mech->post(
    "/media",
    [
        name => 'transform-png',
        file => [ File::Spec->catfile($FindBin::Bin, "data", "test2.png") ],
    ],
    'Content_Type' => 'form-data'
);

$mech->get_ok('/media/transform-png/image/transform', 'null transform ok');
cmp_ok(length($mech->content), '==', 176, 'no transform returns original');

$mech->get_ok('/media/transform-png/image/transform?scale=ypixels:30,xpixels:5,qtype:mixing,type:min', 'scale transform ok');
my $image = Imager->new( data => $mech->content );
isa_ok($image, 'Imager', 'got imager from content');
cmp_ok($image->getwidth, '==', 5, 'right width');
cmp_ok($image->getheight, '==', 5, 'right height');

$mech->get_ok('/media/transform-png/image/transform?scale=ypixels:30,xpixels:5,qtype:mixing,type:max', 'scale transform ok');
my $image = Imager->new( data => $mech->content );
isa_ok($image, 'Imager', 'got imager from content');
cmp_ok($image->getwidth, '==', 30, 'right width');
cmp_ok($image->getheight, '==', 30, 'right height');

$mech->get_ok('/media/transform-png/image/transform?rotate=degrees:50', 'rotate transform ok');
my $image = Imager->new( data => $mech->content );
isa_ok($image, 'Imager', 'got imager from content');
cmp_ok($image->getwidth, '==', 70, 'right width');
cmp_ok($image->getheight, '==', 70, 'right height');

$mech->get_ok('/media/transform-png/image/transform?scale=ypixels:300,xpixels:300&rotate=degrees:50', 'rotate and scale transform ok');
my $image = Imager->new( data => $mech->content );
isa_ok($image, 'Imager', 'got imager from content');
cmp_ok($image->getwidth, '==', 300, 'right width');
cmp_ok($image->getheight, '==', 300, 'right height');

my $uri = URI->new('/media/transform-png', 'http');
   $uri = $mech->base ? URI->new_abs( $uri, $mech->base ) : URI->new( $uri );

$resp = $mech->request( HTTP::Request->new( DELETE => $uri ) );
ok($resp->is_success, 'delete key ok');

$resp = $mech->get("/media/transform-png");
ok(!$resp->is_success, "media doesn't exist");
is($resp->status_line, '404 Not Found', 'not found');

#$mech->get_ok("/media/override-key", 'got media');
my $caption = 'This is just a test at ' . time;
$resp = $mech->post(
    "/media",
    [
        name => 'some-text',
        caption => $caption,
        file => [ File::Spec->catfile($FindBin::Bin, "data", "test.txt") ],
    ],
    'Content_Type' => 'form-data'
);

ok($resp->is_success, 'upload text');

$mech->get_ok("/media/some-text", 'got media');

$mech->get_ok("/media/some-text/embed", 'got embedded media');
$mech->content_contains(
    'This is a test to upload. This should be in the embed content.',
    'embedded text returned ok'
);
$mech->content_contains(
    $caption,
    'embedded text has caption ok'
);

$caption = 'This is just a test later, that has been updated';
$mech->post_ok(
    "/media/some-text",
    {
        name => 'some-text',
        caption => $caption,
    },
);

$mech->get_ok("/media/some-text/embed", 'got embedded media');
$mech->content_contains(
    'This is a test to upload. This should be in the embed content.',
    'embedded text the same'
);

$mech->content_contains(
    $caption,
    'embedded text has caption updated'
);

$caption = 'This is just a test later, that has been updated again.';
# Posting to over-write and update.
$resp = $mech->post(
    "/media",
    [
        name => 'some-text',
        caption => $caption,
        file => [ File::Spec->catfile($FindBin::Bin, "data", "test2.txt") ],
    ],
    'Content_Type' => 'form-data'
);

ok($resp->is_success, 'upload text');

$mech->get_ok("/media/some-text/embed", 'got embedded media');
$mech->content_contains(
    'This is updated content.  It has been reuploaded.',
    'embedded text is updated'
);

$mech->content_contains(
    $caption,
    'embedded text has caption updated'
);

my $uri = URI->new('/media/some-text', 'http');
   $uri = $mech->base ? URI->new_abs( $uri, $mech->base ) : URI->new( $uri );

$resp = $mech->request( HTTP::Request->new( DELETE => $uri ) );
ok($resp->is_success, 'delete key ok');

$resp = $mech->get("/media/some-text");
ok(!$resp->is_success, "text upload doesn't exist");
is($resp->status_line, '404 Not Found', 'not found');

$user->delete;

done_testing;
