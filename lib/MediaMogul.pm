package MediaMogul;

use Moose;
use namespace::autoclean;

use Catalyst::Runtime 5.80;
use CatalystX::RoleApplicator;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    ConfigLoader Static::Simple I18N
    Session Session::Store::FastMmap Session::State::Cookie
    Authentication
    Params::Nested
    +MediaMogul::Plugin::Message
/;

extends 'Catalyst';

our $VERSION = '0.01';
$VERSION = eval $VERSION;

# Configure the application.
#
# Note that settings in mediamogul.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name            => 'MediaMogul',
    default_view    => 'TT',
    authentication  => {
        default_realm => 'users',
        realms => {
            users => {
                credential => {
                    class              => 'Password',
                    password_field     => 'password',
                    password_type      => 'hashed',
                    password_hash_type => 'SHA-512',
                },
                store => {
                    class       => 'FromSub',
                    user_type   => 'Hash',
                    model_class => 'Authorization',
                    id_field    => 'username'
                }
            }
        }
    },
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
);

__PACKAGE__->apply_request_class_roles(qw/
    Catalyst::TraitFor::Request::REST::ForBrowsers
/);

# Start the application
__PACKAGE__->setup();

=head1 CATALYST OVERRIDES

=head2 get_session_id

Fetch the SID from the query parameters in the case of uploads from the YUI
(flash) uploader.

=cut

sub get_session_id {
    my ( $c, @args ) = @_;

    if ( my $sid = $c->request->query_parameters->{SID} ) {
        return $sid;
    }
    return $c->maybe::next::method(@args);
}


=head1 NAME

MediaMogul - Catalyst based application

=head1 SYNOPSIS

    script/mediamogul_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<MediaMogul::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Jay Shirley

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
