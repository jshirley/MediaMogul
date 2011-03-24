package MediaMogul::Controller::Media;

use Moose;

BEGIN { extends 'MediaMogul::Base::Controller::REST::Mongo'; }

use Scalar::Util 'blessed';
use Hash::Diff qw(left_diff);

use URI::Escape;

__PACKAGE__->config(
    actions       => { 'setup' => { PathPart => 'media' } },
    class         => 'Asset',
    create_string => 'The media has been uploaded with the key [_2].',
    update_string => 'The media [_1] has been updated.',
    error_string  => 'There was an error processing the update to your media, please try again.',
    scope => 'asset',
    allow_by_default => 1,
    object_key => 'asset',
    permissions => {
        'root_POST'     => [ '@upload_new', '@admin' ],
        'object_POST'   => [ '@upload_existing', '@admin' ],
        'object_DELETE' => [ '@delete_media', '@admin' ],
    }
);

sub root_POST { 
    my ( $self, $c ) = @_;

    my $data = $c->req->params;
    $data->{create} = 1;

    my $file = $c->req->uploads->{file};
    if ( $file ) {
        $data->{filename}     = $file->filename;
        $data->{file}         = $file->tempname;
        $data->{content_type} = $file->type;
        my $mime = MIME::Types->new->type( $file->type );
        $data->{media_type} = defined $mime ? $mime->mediaType : 'image';
    }
    my $dm      = $c->model('DataManager');
    my $results = $dm->verify('asset', $data);

    unless ( $results->success ) {
        unless ( $c->req->looks_like_browser ) {
            return $self->status_bad_request($c, message => $c->loc('Invalid request'));
        }
        $c->res->redirect($c->uri_for_action('/media/create_form'));
        $c->detach;
    }
    my $values = $dm->data_for_scope('asset');

    my $media = $c->model('Asset')->new($values);
    unless ( $media ) {
        die "Failed creating media";
    }
    my $id = $media->store_file($file);

    my $object_uri = $c->uri_for_action('/media/manage_form', [ $media->name ]);

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
    my $asset = $c->model('Asset')->find_one({ name => $name });
    unless ( defined $asset ) {
        $c->detach('not_found');
    }
    $c->stash->{ $self->object_key } = $asset;
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

    my $file = $c->req->uploads->{file};
    if ( $file ) {
        $data->{filename}     = $file->filename;
        $data->{file}         = $file->tempname;
        $data->{content_type} = $file->type;
        my $mime = MIME::Types->new->type( $file->type );
        $data->{media_type} = defined $mime ? $mime->mediaType : 'image';
    }
    my $dm      = $c->model('DataManager');
    my $results = $dm->verify('asset', $data);

    unless ( $results->success ) {
        unless ( $c->req->looks_like_browser ) {
            return $self->status_bad_request(
                $c, message => $c->loc('Invalid request'));
        }
        $c->res->redirect($c->uri_for_action('/media/manage_form'));
        $c->detach;
    }
    my $values = $dm->data_for_scope('asset');
    my $media  = $c->stash->{ $self->object_key };

    delete $values->{name}; 
    foreach my $value ( keys %$values ) {
        my $attr = $media->meta->get_attribute($value);
        next unless defined $attr;
        if ( my $writer = $attr->accessor ) {
            $media->$writer( $values->{$value} );
        }
    }

    if ( $file ) {
        $media->store_file($file);
    } else {
        $media->store;
    }

    my $object_uri = $c->uri_for_action('/media/manage_form', [ $media->name ]);

    unless ( $c->req->looks_like_browser ) {
        $c->res->body('ok.'); # Some clients won't serialize ok. The serializer
                              # should still work in this case.
        return $self->status_ok(
            $c,
            entity   => $media->pack
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
    $c->message($c->loc('The media has been removed'));
    $c->res->redirect($c->uri_for_action('/media/root'));
    $c->detach;
}

sub display : Chained('object_setup') Args(0) {
    my ( $self, $c ) = @_;
    my $media = $c->stash->{$self->object_key};
    unless ( $media->has_file ) {
        $c->res->content_type('text/plain');
        $c->res->body($c->loc("Media [_1] does not have any file data. Try uploading again.", [ $media->name ]));
        $c->detach;
    }
    my $data = $media->get_file;
    unless ( defined $data ) {
        $c->res->status(400);
        $c->res->content_type('text/plain');
        $c->res->body($c->loc("Media [_1] does not have any file data, but should. Corrupted entry?", [ $media->name ]));
        $c->detach;
    }

    $c->res->content_type( $data->info->{content_type} );
    $c->res->body( $data->slurp );
}

sub embed : Chained('object_setup') Args(0) {
    my ( $self, $c ) = @_;

    my $asset = $c->stash->{ $self->object_key };

    $c->stash->{page}->{layout} = 'partial';

    # Render the URL for the public facing
    my $media_uri = $c->uri_for_action('/media/display', [ $asset->name ]);
    unless ( $c->debug and $c->config->{public_host} ) {
        $media_uri->host( $c->config->{public_host} );
    }
    $c->stash->{media_uri} = $media_uri;
    my $profile  = $asset->template || 'default';
    my $type     = $asset->media_type;
    my $template;
    if ( -f $c->path_to('templates', $type, "$profile.tt") ) {
        $template = join('/', $type, "$profile.tt");
    }
    elsif ( -f $c->path_to('templates', $type, "default.tt") ) {
        $template = join('/', $type, "default.tt");
    } else {
        $c->res->status(400);
        $c->res->body($c->loc('No view for type: [_1].', [ $type ]));
    }
    $c->log->debug("Template is $template");
    $c->stash->{template} = $template;
    $c->forward( $c->view('Media') );
}

sub manage_form : Chained('object_setup') PathPart('manage') Args(0) { }


no Moose;
__PACKAGE__->meta->make_immutable; 1;