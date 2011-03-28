#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use_ok('MediaMogul::User');
use_ok('MediaMogul::DataManager');

{
    my $user = MediaMogul::User->new(
        username => 'test',
        password => 'password'
    );
    isa_ok($user, 'MediaMogul::User', 'created user');
    ok($user->check_password('password'), 'check_password ok');
    is($user->password, 'b109f3bbbc244eb82441917ed06d618b9008dd09b3befd1b5e07394c706a8bb980b1d7785e5976ec049b46df5f1326af5a2ea6d103fd07c95385ffab0cacbc86', 'digest password');
}

{
    throws_ok
        { MediaMogul::User->new( username => 'invalid' ) }
        qr/Must supply a password/, 'Missing password exception';
}

{
    my $user = MediaMogul::User->new(
        username => 'invalid',
        _password => 'raw password'
    );
    
    isa_ok($user, 'MediaMogul::User', 'created user');
    ok(!$user->check_password('raw password'), 'check_password not ok');
    is($user->password, 'raw password', 'kept raw password');
}

{
    my $dm = MediaMogul::DataManager->new_from_classes(
        'MediaMogul::User',
    );
    my $results = $dm->verify('user', { });
    ok( !$results->success, 'expected verification failed' );

    $results = $dm->verify('user', { username => 'bob' });
    ok( !$results->success, 'expected verification failed' );

    $results = $dm->verify('user', { username => 'bob', password => 'bob' });
    ok( !$results->success, 'expected verification failed' );
    
    $results = $dm->verify('user',
        { username => 'bob', password => 'bob', confirm_password => 'baz' }
    );
    ok( !$results->success, 'expected verification failed' );

    $results = $dm->verify('user',
        { username => 'bob', password => 'bob', confirm_password => 'bob' }
    );
    ok( $results->success, 'expected verification passed' );

    $results = $dm->verify('user',
        { username => 'bob', password => 'bob', confirm_password => 'bob ' }
    );
    ok( $results->success, 'expected verification passed with filter' );
    ok( $dm->success, 'Data::Manager instance passes' );

    $results = $dm->verify('user',
        {
            username => 'bob',
            password => 'bob', confirm_password => 'bob',
            permissions => [ '@admin' ]
        }
    );
    ok( $results->success, 'validation passed with permissions' );
    is_deeply(
        $results->get_value('permissions'),
        { '@admin' => 1 },
        'permissions ok'
    );
}

done_testing;
