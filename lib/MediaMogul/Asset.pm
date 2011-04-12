package MediaMogul::Asset;

use Moose;
use MooseX::Storage;

use Scalar::Util 'blessed';
use Data::Verifier;
use namespace::clean -except => 'meta';

with Storage(             # Implementations for these are in this dist, at:
    'format' => 'Moose',  #  - MooseX::Storage::Format::Moose
    'io'     => 'Mongo'   #  - MooseX::Storage::IO::Mongo
);

with 'MooseX::Traits';
has '+_trait_namespace' => ( 'default' => 'MediaMogul::Asset' );

with qw(MooseX::Clone);

use Try::Tiny;

has 'name' => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1
);

has [ 'caption', 'source', 'source_url', 'note' ] => (
    is          => 'rw',
    isa         => 'Str',
);

has 'file_uuid' => (
    is          => 'rw',
    isa         => 'ArrayRef[MongoDB::OID]',
    predicate   => 'has_file',
    traits      => [ 'Array' ],
    default     => sub { [] },
    handles => {
        'add_file_uuid'   => 'push',
        'get_file_uuid'   => 'get',
        'file_uuid_count' => 'count',
        'all_file_uuids'  => 'elements',
    }
);

sub last_file_uuid {
    my ( $self ) = @_;
    $self->get_file_uuid( $self->file_uuid_count - 1 );
}

after 'delete' =>sub {
    my $self = shift;
    my $mfs = $self->_get_mongo_database->get_gridfs;
    foreach my $uuid ( $self->all_file_uuids ) {
        $mfs->delete( $uuid );
    }
};

has '_verifier' => (
    is          => 'ro',
    isa         => 'HashRef[Data::Verifier]',
    lazy_build  => 1,
    traits      => [ 'DoNotSerialize' ]
);

sub _build__verifier {
    my ( $self ) = @_;

    my $verifier = Data::Verifier->new(
        filters => [ 'trim' ],
        profile => {
            name => {
                type     => 'Str',
                required => 1,
            },
            caption => {
                type => 'Str',
            },
            source => {
                type => 'Str',
            },
            source_url => {
                type => 'Str',
            },
            note => {
                type => 'Str',
            },
            template => {
                type => 'Str',
            },
            content_type => {
                type => 'Str',
            },
            create => {
                type => 'Bool',
                dependent => {
                    filename => {
                        type    => 'Str',
                        required => 1,
                    },
                    # Temp file
                    file => {
                        type     => 'Str',
                        required => 1
                    },
                    content_type => {
                        type => 'Str',
                    }
                },
            },
            update => {
                type => 'Bool',
                dependent => {
                    filename => {
                        type    => 'Str',
                    },
                    file => {
                        type     => 'Str',
                    },
                    content_type => {
                        type => 'Str',
                    },
                },
            },
        }
    );
    return { asset => $verifier };
}

sub as_results {
    my ( $self ) = @_;
    my ( $verifier ) = values %{ $self->_verifier };
    return $verifier->verify( $self->pack );
}

sub store_file {
    my ( $self, $file ) = @_;
    my $gfs = $self->_get_mongo_database->get_gridfs;
    my $id;

    # TODO It would be useful to check this and not upload if it is a duplicate.
    # We'd have to calculate the MD5 of the file on disk, which could be
    # costly (then find something in the collection and just add the UUID to
    # the top of the stack and return.

    if ( blessed $file and $file->isa('Catalyst::Request::Upload') ) {
        $id = $gfs->insert(
            $file->fh,
            {
                filename     => $file->filename,
                content_type => $file->type,
                size         => $file->size
            },
            { safe => 1 }
        );
    } else {
        die "TODO: Handle storing a file that isn't a Catalyst::Request::Upload";
    }
    if ( not defined $id ) {
        die "Unable to save into GridFS";
    }
    $self->add_file_uuid( $id );
    $self->store;
}

sub get_file {
    my ( $self ) = @_;
    if ( $self->has_file ) {
        return $self->_get_mongo_database->get_gridfs->get($self->last_file_uuid);
    }
    return undef;
}

has 'mime_type' => (
    is          => 'ro',
    isa         => 'MIME::Type',
    traits      => [ 'DoNotSerialize' ],
    lazy_build  => 1,
    handles => {
        'media_type' => 'mediaType',
    }
);

sub _build_mime_type {
    my ( $self ) = @_;
    return MIME::Types->new->type( $self->content_type );
}

has 'content_type' => (
    is          => 'rw',
    isa         => 'Str',
    default     => 'text/plain'
);

has 'template' => (
    is          => 'rw',
    isa         => 'Str',
    predicate   => 'has_template'
);

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable; 1;
