package MediaMogul::Controller::Admin::Site;

use Moose;

BEGIN { extends 'MediaMogul::Base::Controller::REST::Mongo'; }

use Scalar::Util 'blessed';
use Hash::Diff qw(left_diff);

use URI::Escape;

__PACKAGE__->config(
    actions       => { 'setup' => { PathPart => 'site' } },
    class         => 'Site',
    create_string => 'The site has been created with the key [_2].',
    update_string => 'The site [_1] has been updated.',
    error_string  => 'There was an error processing the update to your media, please try again.',
    scope => 'site',
    allow_by_default => 0,
    object_key => 'site',
    permissions => {
        'setup'     => [ '@admin' ],
    }
);

sub root_POST {
    my ( $self, $c ) = @_;

    my $data = $c->req->params;
    $data->{create} = 1;

    my $dm      = $c->model('DataManager');
    my $results = $dm->verify('site', $data);

    unless ( $results->success ) {
        unless ( $c->req->looks_like_browser ) {
            return $self->status_bad_request($c, message => $c->loc('Invalid request'));
        }
        $c->res->redirect($c->uri_for_action('/admin/site/create_form'));
        $c->detach;
    }
    my $values = $dm->data_for_scope('site');

    my $site = $c->model('Site')->find_one({ name => $values->{name} }) ||
                $c->model('Site')->new($values);
    unless ( $site ) {
        die "Failed creating site";
    }
    if ( $site->has_mongo_id ) {
        delete $values->{name}; 
        foreach my $value ( keys %$values ) {
            my $attr = $site->meta->get_attribute($value);
            next unless defined $attr;
            if ( my $writer = $attr->accessor ) {
                $site->$writer( $values->{$value} );
            }
        }
    }
    my $id = $site->store;

    my $object_uri = $c->uri_for_action('/admin/site/manage_form', [ $site->name ]);

    unless ( $c->req->looks_like_browser ) {
        return $self->status_created($c,
            location => "$object_uri",
            entity => { uuid => $id }
        );
    }

    $c->message($c->loc($self->create_string));
    $c->res->redirect($object_uri);

    $c->detach;
}

sub root_GET {
    my ( $self, $c ) = @_;

    return if $c->req->looks_like_browser;

    return $self->status_ok( $c, { entity => { results => [] } } );
}

sub create_form : Chained('setup') PathPart('create') Args(0) { }

sub object_setup : Chained('setup') PathPart('') CaptureArgs(1) {
    my ( $self, $c, $name ) = @_;
    my $site = $c->model('Site')->find_one({ name => $name });
    unless ( defined $site ) {
        $c->detach('not_found');
    }
    $c->stash->{ $self->object_key } = $site;
}

sub object_GET { 
    my ( $self, $c ) = @_;
    unless ( $c->req->looks_like_browser ) {
        return $self->status_ok(
            $c,
            entity => { asset => $c->stash->{ $self->object_key }->pack }
        );
    }
}

sub object_POST {
    my ( $self, $c ) = @_;

    my $data = $c->req->params;
    $data->{update} = 1;

    my $dm      = $c->model('DataManager');
    my $results = $dm->verify('site', $data);

    unless ( $results->success ) {
        unless ( $c->req->looks_like_browser ) {
            return $self->status_bad_request(
                $c, message => $c->loc('Invalid request'));
        }
        $c->res->redirect($c->uri_for_action('/admin/site/manage_form'));
        $c->detach;
    }

    my $values = $dm->data_for_scope('asset');
    my $site   = $c->stash->{ $self->object_key };

    delete $values->{name};
    foreach my $value ( keys %$values ) {
        my $attr = $site->meta->get_attribute($value);
        next unless defined $attr;
        if ( my $writer = $attr->accessor ) {
            $site->$writer( $values->{$value} );
        }
    }

    $site->store;

    my $object_uri = $c->uri_for_action('/admin/site/manage_form', [ $site->name ]);

    unless ( $c->req->looks_like_browser ) {
        $c->res->body('ok.'); # Some clients won't serialize ok. The serializer
                              # should still work in this case and clobber
                              # the ok (or return 'ok' in the case of no
                              # matching content-type to serialize to.
        return $self->status_ok(
            $c,
            entity => $site->pack
        );
    }

    $c->message($c->loc($self->update_string));
    $c->res->redirect($object_uri);

    $c->detach;
}

sub object_DELETE {
    my ( $self, $c ) = @_;
    $c->stash->{ $self->object_key }->delete;
    unless ( $c->req->looks_like_browser ) {
        return $self->status_accepted(
            $c, entity => { status => $c->loc('Deleted') }
        );
    }
    $c->message($c->loc('The site has been removed'));
    $c->res->redirect($c->uri_for_action('/admin/site/root'));
    $c->detach;
}

sub manage_form : Chained('object_setup') PathPart('manage') Args(0) { }

no Moose;
__PACKAGE__->meta->make_immutable; 1;
