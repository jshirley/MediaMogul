package MediaMogul::Controller::Authentication;

use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

MediaMogul::Controller::Authentication - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub login : Chained('.') Args(0) {
    my ( $self, $c ) = @_;

    my $count = $c->model('User')->query->count;
    if ( $count == 0 ) {
        $c->res->redirect($c->uri_for_action('/authentication/first_user'));
        $c->detach;
    }

    if ( $c->req->method eq 'POST' ) {
        my $data = $c->req->params;
        if ( $c->authenticate({ username => $data->{username}, password => $data->{password} }) ) {
            unless ( $c->req->looks_like_browser ) {
                $c->res->body('Login ok');
                $c->detach;
            }
            $c->message( $c->loc("Welcome back!") );
            my $source = $c->uri_for_action('/media/root');
            if ( my $dest = $c->req->params->{source} ) {
                $dest = URI->new($dest);
                if ( $dest and $dest->host eq $source->host ) {
                    $source = $dest;
                }
            }
            $c->res->redirect( $source );
            if ( $c->user_in_realm('temp') ) {
                $c->message({ type => 'warning', message => $c->loc('You must change your password to proceed') });
                $c->res->redirect( $c->uri_for_action('/profile/password') );
            }
            $c->detach;
        }
        unless ( $c->req->looks_like_browser ) {
            $c->res->status(403);
            $c->res->body($c->loc('Invalid login'));
            $c->detach;
        }
        $c->message({ type => 'error', message => $c->loc('Invalid Login') });
        $c->res->redirect( $c->uri_for_action('/authentication/login') );
        $c->detach;
    }
}

sub first_user : Chained('.') Args(0) {
    my ( $self, $c ) = @_;

    my $count = $c->model('User')->query->count;
    if ( $count > 0 ) {
        $c->res->redirect($c->uri_for_action('/authentication/login'));
        $c->detach;
    }

    if ( $c->req->method eq 'POST' ) {
        my $data = $c->req->params;
           $data->{user}->{permissions} = [ '@admin' ];

        my $dm   = $c->model('DataManager');
        my $results = $dm->verify('user', $data->{user});
        unless ( $results->success ) {
            $c->res->redirect($c->uri_for_action($c->action));
            $c->detach;
        }
        $c->log->_dump( $dm->data_for_scope('user') );
        my $user = $c->model('User')->new( $dm->data_for_scope('user') );
        $user->store;
        $c->message($c->loc('User account created, you can login now!'));
        $c->res->redirect($c->uri_for_action('/authentication/login'));
        $c->detach;
    }
}

sub logout : Chained('.') Args(0) {
    my ( $self, $c ) = @_;
    $c->message($c->loc("You've been logged out, come back soon!"));

    $c->logout;
    $c->delete_session;

    $c->res->redirect( $c->uri_for_action('/authentication/login'), 303 );
    $c->detach;
}

sub forgot_password : Chained('.') Args(0) {
    my ( $self, $c ) = @_;
    if ( $c->req->method eq 'POST' ) {
        my $dest   = $c->uri_for_action('/authentication/forgot_password');
        my $email  = $c->req->params->{email};
        if ( not $email ) {
            $c->message({
                type => 'error',
                message => $c->loc('Please provide an email address.')
            });
            $c->res->redirect( $dest, 303 );
            $c->detach;
        }
        my $person = $email ?
            $c->model('User')->find({ username => $email }) : undef;
        if ( $person ) {
            my $temp  = $person->temporary_password;
            $c->model('Correspondence')->send(
                'forgot_password',
                {
                    subject     => $c->loc("MediaMogul Temporary Password"),
                    email       => $person->email,
                    username    => $person->username,
                    login_url   => $c->uri_for_action('/authentication/login'),
                    temporary_password => $temp,
                }
            );
            $c->message($c->loc('A temporary password has been sent to the email on file'));
            $dest = $c->uri_for_action('/authentication/login');
        } else {
            $c->message({ type => 'error', message => $c->loc('Unable to send temporary password.  Please verify the email address ([_1])', [ $email ] ) });
        }
        $c->res->redirect( $dest, 303 );
        $c->detach;
    }
}

=head1 AUTHOR

Jay Shirley

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
