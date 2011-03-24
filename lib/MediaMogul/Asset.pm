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

has [ 'caption', 'source' ] => (
    is          => 'rw',
    isa         => 'Str',
);

has 'file_uuid' => (
    is          => 'rw',
    isa         => 'MongoDB::OID',
    predicate   => 'has_file'
);

after 'delete' =>sub {
    my $self = shift;
    my $mfs = $self->_get_mongo_database->get_gridfs;
    $mfs->delete( $self->file_uuid );
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
            template => {
                type => 'Str',
            },
            media_type => {
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

sub store_file {
    my ( $self, $file ) = @_;
    my $gfs = $self->_get_mongo_database->get_gridfs;
    my $id;
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
    if ( $self->has_file ) {
        $gfs->delete($self->file_uuid);
    }
    $self->file_uuid( $id );
    $self->store;
}

sub get_file {
    my ( $self ) = @_;
    if ( $self->has_file ) {
        return $self->_get_mongo_database->get_gridfs->get($self->file_uuid);
    }
    return undef;
}

has 'media_type' => (
    is          => 'rw',
    isa         => 'Str', # Really an enum
    default     => 'image'
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
