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

has 'profiles_by_type' => (
    is  => 'ro',
    isa => 'HashRef[HashRef[ArrayRef]]',
    default => sub { {
        'image' => {
            'thumbnail' => [ '/media/image/transform/root', { scale => 'ypixels:300,xpixels:300,type:min' } ],
            'blog' => [ '/media/image/transform/root', { scale => 'ypixels:500,xpixels:500,type:min' } ],
        }
    } },
    traits => [ 'Hash' ],
    handles => {
        'get_profiles_for_type' => 'get'
    }
);

sub root_POST {
    my ( $self, $c ) = @_;

    my $data = $c->req->params->{asset} || {};
    $data = {} unless ref $data eq 'HASH';
    $data->{create} = 1;

    my $file = $c->req->uploads->{file} || $c->req->uploads->{Filedata};
    if ( $file ) {
        $data->{filename}     = $file->filename;
        $data->{file}         = $file->tempname;
        $data->{content_type} = $file->type;

        if ( my $new_key = $c->req->params->{'file.' . $data->{filename}} ) {
            $data->{name} = $new_key;
        }
        my $mt   = MIME::Types->new;
        my $mime = $mt->type( $file->type );
        $data->{media_type} = defined $mime ? $mime->mediaType : 'image';
        # Any application we're going to refine using the extension
        if ( $data->{media_type} eq 'application' ) {
            $data->{filename} =~ /\.(.*?)$/;
            my $ext = $1;
            if ( $ext ) {
                my $def = $mt->mimeTypeOf($ext);
                $data->{media_type} = $def->mediaType;
                $data->{content_type} = "$def";
                $file->type("$def"); # The client is a lie!
            }
        }
        $data->{name} ||= $data->{filename};
    }
    my $dm      = $c->model('DataManager');
    my $results = $dm->verify('asset', $data);

    unless ( $results->success ) {
        unless ( $c->req->looks_like_browser ) {
            $c->log->_dump($results);
            return $self->status_bad_request($c, message => $c->loc('Invalid request'));
        }
        $c->res->redirect($c->uri_for_action('/media/create_form'));
        $c->detach;
    }
    my $values = $dm->data_for_scope('asset');
    $c->log->_dump($values);
    my $media = $c->model('Asset')->find_one({ name => $values->{name} }) ||
                $c->model('Asset')->new($values);
    unless ( $media ) {
        die "Failed creating media";
    }
    if ( $media->has_mongo_id ) {
        delete $values->{name}; 
        foreach my $value ( keys %$values ) {
            my $attr = $media->meta->get_attribute($value);
            next unless defined $attr;
            if ( my $writer = $attr->accessor ) {
                $media->$writer( $values->{$value} );
            }
        }
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
    
    my $results = $c->model('Search')->search;
    $c->stash->{results} = $results;

    return if $c->req->looks_like_browser;

    return $self->status_ok( $c, { entity => { results => $results->pack } } );
}

sub search : Chained('setup') Args(0) ActionClass('REST') {
    my ( $self, $c ) = @_;
    $c->req->content_type('application/json');

    # Need to actually do the querying and what not here. Create a D::SE query
    # object and pass it into Search.
    my $results = $c->model('Search')->search;
    my @sort    = ( 'name', 'desc' );

    my $items = [
        map {
            my $values = $_->values;
            $values->{actions} = {
                $c->loc('Edit') => $c->uri_for_action('/media/manage_form', [ $values->{name} ])->as_string,
            };
            $values;
        } @{ $results->items }
    ];
    return $self->status_ok(
        $c,
        {
            entity => {
                results => $items,
                query   => '.*',
                facets  => {},
                filters => {},
                pager   => {
                    current_page     => $results->pager->current_page,
                    entries_per_page => $results->pager->entries_per_page,
                    total_entries    => $results->pager->total_entries,
                    first_page       => $results->pager->first_page,
                    last_page        => $results->pager->last_page,
                    first            => $results->pager->first,
                    last             => $results->pager->last,
                },
                sort => {
                    lastSortedBy => $sort[0],
                    direction    => $sort[1]
                }

            }
        }
    );
}
sub search_GET { }

sub create_form : Chained('setup') PathPart('create') Args(0) { }

sub object_setup : Chained('setup') PathPart('') CaptureArgs(1) {
    my ( $self, $c, $name ) = @_;
    my $asset = $c->model('Asset')->find_one({ name => $name });
    unless ( defined $asset ) {
        $c->detach('not_found');
    }
    $c->stash->{ $self->object_key } = $asset;
}

sub image : Chained('object_setup') PathPart('') CaptureArgs(0) {
    my ( $self, $c ) = @_;
    my $asset = $c->stash->{ $self->object_key };
    unless ( $asset->media_type eq 'image' ) {
        $c->res->status(400);
        $c->res->body($c->loc("Media is not of type image, it is a [_1].", [ $asset->media_type ]));
        $c->detach;
    }
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

    my $data = $c->req->params->{asset} || {};
    $data = {} unless ref $data eq 'HASH';

    $data->{update} = 1;

    my $file = $c->req->uploads->{file};

    if ( $file ) {
        $data->{filename}     = $file->filename;
        $data->{file}         = $file->tempname;
        $data->{content_type} = $file->type;
        # XX This is the same as in root_POST, need to generalize this more
        my $mt   = MIME::Types->new;
        my $mime = $mt->type( $file->type );
        $data->{media_type} = defined $mime ? $mime->mediaType : 'image';
        # Any application we're going to refine using the extension
        if ( $data->{media_type} eq 'application' ) {
            $data->{filename} =~ /\.(.*?)$/;
            my $ext = $1;
            if ( $ext ) {
                my $def = $mt->mimeTypeOf($ext);
                $data->{media_type} = $def->mediaType;
                $data->{content_type} = "$def";
                $file->type("$def"); # The client is a lie!
            }
        }
        $data->{name} ||= $data->{filename};

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

    $media->store;
    if ( $file ) {
        $c->log->debug("Storing file $file");
        $media->store_file($file);
    }

    my $object_uri = $c->uri_for_action('/media/manage_form', [ $media->name ]);

    unless ( $c->req->looks_like_browser ) {
        $c->res->body('ok.'); # Some clients won't serialize ok. The serializer
                              # should still work in this case and clobber
                              # the ok (or return 'ok' in the case of no
                              # matching content-type to serialize to.
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
    my $name = $media->name;
        $name =~ s/"/&quot;/g;
    $c->response->headers->header('Content-disposition:' =>
        qq{attachment; filename="$name"} );
    $c->res->body( $data->slurp );
}

sub generate_embed : Private {
    my ( $self, $c, $asset, $profile ) = @_;

    # Render the URL for the public facing
    my $media_uri = $c->uri_for_action('/media/display', [ $asset->name ]);
    if ( $profile ) {
        my $profiles = $self->get_profiles_for_type($asset->media_type);
        if ( $profiles and my $defaults = $profiles->{$profile} ) {
            $media_uri = $c->uri_for_action($defaults->[0], [ $asset->name ], $defaults->[1]);
        }
    }
    unless ( $c->debug and $c->config->{public_host} ) {
        $media_uri->host( $c->config->{public_host} );
    }
    $c->stash->{media_uri} = $media_uri;

    my $tmpl = $asset->template || 'default';
    my $type = $asset->media_type;

    my $template;
    if ( -f $c->path_to('templates', $type, "$tmpl.tt") ) {
        $template = join('/', $type, "$tmpl.tt");
    }
    elsif ( -f $c->path_to('templates', $type, "default.tt") ) {
        $template = join('/', $type, "default.tt");
    } else {
        $c->res->status(400);
        $c->res->body($c->loc('No view for type: [_1].', [ $type ]));
    }
    $c->log->debug("Template is $template");
    $c->stash->{embed_output} = $c->view('Media')->render($c, $template);
}

sub embed : Chained('object_setup') Args(0) {
    my ( $self, $c ) = @_;
    my $asset = $c->stash->{ $self->object_key };
    $c->forward('generate_embed', [ $asset, $c->req->params->{profile} ]);

    $c->res->body($c->stash->{embed_output});
}

sub manage_form : Chained('object_setup') PathPart('manage') Args(0) {
    my ( $self, $c ) = @_;

    my $asset   = $c->stash->{ $self->object_key };
    my $results = $c->stash->{results}->{asset};
    if ( not $results ) {
        $c->stash->{results}->{asset} = $asset->as_results;
    }
    $c->forward('generate_embed', [ $asset, 'thumbnail' ]);
}


no Moose;
__PACKAGE__->meta->make_immutable; 1;
