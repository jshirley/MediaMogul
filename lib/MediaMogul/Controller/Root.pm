package MediaMogul::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

MediaMogul::Controller::Root - Root Controller for MediaMogul

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    if ( $c->user_exists ) {
        $c->res->redirect($c->uri_for_action('media/root'));
    } else {
        $c->res->redirect($c->uri_for_action('authentication/login'));
        $c->message($c->loc('Login to get started.'));
    }
}

sub crossdomain :Path('crossdomain.xml') :Args(0) { 
    my ( $self, $c ) = @_;
    # XX Figure out exactly what this should be
    my $domain = $c->debug ? "*" : "*";
    $c->res->content_type('application/xml');
    $c->res->body(
qq{<?xml version="1.0" ?>
<cross-domain-policy>
  <site-control permitted-cross-domain-policies="master-only"/>
  <allow-access-from domain="$domain"/>
  <allow-http-request-headers-from domain="$domain" headers="*"/>
</cross-domain-policy>
});
}

sub guide :Path('guide') :Args(0) { }

sub setup : Chained('/') PathPart('') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    if ( $c->user_exists ) {
        $c->stash->{context}->{permissions} = $c->user->{permissions};
    }
}

sub authentication : Chained('/') PathPart('') CaptureArgs(0) { }

sub login_required  : Chained('setup') PathPart('') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    unless ( $c->user_exists ) {
        $c->res->redirect(
            $c->uri_for_action('/authentication/login', { source => $c->req->uri } )
        );
        $c->log->info("No user for " . $c->req->uri . ", redirecting to: " . $c->res->location);
        $c->detach;
    }

    if ( $c->user_in_realm('temp') ) {
        if ( $c->action->namespace ne 'profile' ) {
            $c->message({
                type => 'warning',
                message => $c->loc('You must change your password to continue')
            });
            $c->res->redirect( $c->uri_for_action('/profile/root') );
            $c->detach;
        }
    }
}

sub media : Chained('setup') PathPart('') CaptureArgs(0) { }
sub admin : Chained('login_required') PathPart('') CaptureArgs(0) { }

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

Jay Shirley

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
