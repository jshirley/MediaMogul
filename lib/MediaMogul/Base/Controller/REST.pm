package MediaMogul::Base::Controller::REST;

use Moose;
use Try::Tiny;

BEGIN { extends 'Catalyst::Controller::REST'; }

__PACKAGE__->config(
    'default' => 'text/html',
    map => {
        'text/html'  => [ 'View', 'TT' ],
        'text/xhtml' => [ 'View', 'TT' ],
        # We do not suppor XML serialization, and this fixes Safari being
        # retarded.
        'text/xml'   => [ 'View', 'TT' ],
    },
    update_string => 'Your object has been updated.',
    create_string => 'Your object has been created.',
    error_string => 'There was an error creating your object.',
);

has 'object_key' => (
    is      => 'rw',
    isa     => 'Str',
    default => 'object'
);

has 'scope' => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_default_scope'
);

has 'access_check' => (
    is  => 'rw',
    isa => 'CodeRef',
    predicate => 'has_access_check'
);

has 'order_by' => (
    is  => 'rw',
    isa => 'Str|ArrayRef|HashRef',
    default => '',
    predicate => 'has_order_by',
);

has 'create_string' => (
    is  => 'rw',
    isa => 'Str',
    default => 'Your object has been created.'
);

has 'update_string' => (
    is  => 'rw',
    isa => 'Str',
    default => 'Your object has been updated.'
);

has 'error_string' => (
    is  => 'rw',
    isa => 'Str',
    default => 'There was a problem processing your request.'
);

has 'permissions' => (
    is      => 'rw',
    isa     => 'HashRef',
    traits  => [ 'Hash' ],
    default => sub { { } },
    lazy    => 1,
    handles => {
        'get_permission_for_action' => 'get',
        'has_permissions' => 'count',
    }
);

has 'allow_by_default' => (
    is      => 'rw',
    isa     => 'Bool',
    default => sub { 1; },
    lazy    => 1,
);

sub setup : Chained('.') PathPart('') CaptureArgs(0) {
    my ( $self, $c ) = @_;

    if ( $self->has_default_scope ) {
        $c->stash->{nav_item} = $self->scope;
        $c->stash->{context}->{scope} = $self->scope
    }

    my $action = $c->action->name;
    my $perm = $self->get_permission_for_action( $action );
    if ( $c->req->method ne 'GET' and not defined $perm ) {
        # Not a GET request, so look up the $action_PUT style actions that
        # Catalyst::Controller::REST uses.
        $perm = $self->get_permission_for_action( $action . '_' . $c->req->method);
        $c->log->debug("Nothing on top level, checking req method: $action") if $c->debug;
    }
    # Still don't have permissions, look at setup
    if ( not defined $perm ) {
        $perm = $self->get_permission_for_action( 'setup' );
    }

    if ( not defined $perm and not $self->allow_by_default ) {
        $c->log->error("Action misconfiguration! allow_by_default is off but this action ($action) has no permissions configured (nor a setup action)");
        $c->detach('permission_denied');
    }
    elsif ( defined $perm and
            not grep { exists $c->stash->{context}->{permissions}->{$_} } @$perm
    ) {
        $c->log->info(
            "Access denied for user: " . 
            ( $c->user_exists ? $c->user->name : 'anonymous' ) .
            ", require permissions @$perm, only has: " .
            join(', ', keys %{ $c->stash->{context}->{permissions} } )
        );
        $c->detach('permission_denied');
    }

    if ( $self->meta->has_attribute('rs_key') ) {
        $c->stash->{ $self->rs_key } = $self->_fetch_rs( $c );
    }
}

sub root : Chained('setup') PathPart('') Args(0) ActionClass('REST') { }
sub root_GET  { }

sub create_form : Chained('setup') PathPart('create') Args(0) { 
    my ( $self, $c ) = @_;

    if ( $self->has_access_check ) {
        try {
            $self->access_check( $c );
        } catch {
            $c->detach('access_denied');
        };
    }
    $c->stash->{scope}    = 'create';
    $c->stash->{template} = $c->action->namespace . "/create_form.tt";
    #$c->log->_dump({ results => $c->stash->{results} });
}


sub object_setup : Chained('setup') PathPart('id') CaptureArgs(1) { }
sub object : Chained('object_setup') PathPart('') Args(0) ActionClass('REST') {}
sub object_GET { }

sub permission_denied : Private {
    my ( $self, $c ) = @_;

    $c->res->status(403);
    if ( $c->req->looks_like_browser ) {
        $c->stash->{template} = 'errors/403.tt';
    } else {
        $c->res->body("Permission denied to perform the requested action");
    }
    $c->detach;
}

# Just designed to override this.
sub prepare_data { shift; shift; $_[0]; }


sub access_denied : Private {
    my ( $self, $c ) = @_;
    $c->res->status(403);
    $c->stash->{template} = $c->action->namespace . "/create_form.tt";
    $c->detach;
}

sub not_found : Private { 
    my ( $self, $c ) = @_;
    $c->res->status(404);
    unless ( $c->req->looks_like_browser ) {
        return $self->status_not_found($c, message => $c->loc("Not found"));
    }

    if ( $c->action->namespace =~ /^media/ ) {
        # Don't render a template for the media controller
        $c->res->body( $c->loc("Not found") );
    } else {
        $c->stash->{template} = $c->action->namespace . "/not_found.tt";
    }
}

sub end : ActionClass('Serialize') { }

no Moose;
__PACKAGE__->meta->make_immutable;
