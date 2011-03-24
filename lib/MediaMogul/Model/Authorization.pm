package MediaMogul::Model::Authorization;

use MediaMogul::User;

use warnings;
use strict;

use parent 'Catalyst::Model';

sub auth {
    my ( $self, $c, $userinfo ) = @_;

    my $user;

    if ( exists $userinfo->{username} ) {
        $user = MediaMogul::User->find_one({ username => $userinfo->{username} })
    }

    return undef unless defined $user;

    return {
        id          => $user->_id,
        username    => $user->username,
        password    => $user->password,
        permissions => $user->permissions,
        roles       => [ $user->all_permissions ]
    };
}

1;

