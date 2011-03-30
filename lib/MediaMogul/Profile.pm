package MediaMogul::Profile;

use Moose;
use MooseX::Storage;

use Try::Tiny;
use Digest;

use Data::Verifier;

use namespace::clean -except => 'meta';

with Storage(             # Implementations for these are in this dist, at:
    'format' => 'Moose',  #  - MooseX::Storage::Format::Moose
    'io'     => 'Mongo'   #  - MooseX::Storage::IO::Mongo
);

has 'name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'media_type' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'action' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'arguments' => (
    is      => 'ro',
    isa     => 'HashRef',
    default => sub { { } }
);

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
            media_type => {
                type     => 'Str',
                required => 1,
            },
            action => {
                type     => 'Str',
                required => 1,
            },
            template => {
                type => 'Str',
            },
            arguments => {
                type => 'HashRef[Str]',
            },
        }
    );
    return { profile => $verifier };
}

sub as_results {
    my ( $self ) = @_;
    my ( $verifier ) = values %{ $self->_verifier };
    return $verifier->verify( $self->pack );
}


no Moose;
__PACKAGE__->meta->make_immutable;
