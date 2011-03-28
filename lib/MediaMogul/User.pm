package MediaMogul::User;

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

around 'BUILDARGS' => sub {
    my $orig  = shift;
    my $class = shift;

    my %args  = @_ == 1 && ref $_[0] ? %{ $_[0] } : @_;
    unless ( $args{_password} ) {
        die "Must supply a password" unless $args{password};

        my $digest = $class->_build_digester;
        $digest->add($args{password});
        $args{_password} = $digest->hexdigest;
    }
    return $class->$orig(%args);
};

has 'username' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has '_password' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

sub password { shift->_password(); }

sub set_password {
    my ( $self, $password ) = @_;
    $self->_password( $self->_digest_hex($password) );
}

has 'permissions' => (
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { { } },
    traits  => [ 'Hash' ],
    handles => {
        'get_permission'  => 'get',
        'has_permission'  => 'exists',
        'all_permissions' => 'keys',
    }
);

sub check_password {
    my ( $self, $password ) = @_;
    return $self->_password eq $self->_digest_hex($password);
}

has 'digester' => (
    is      => 'ro',
    isa     => 'Digest::SHA',
    traits  => [ 'DoNotSerialize' ],
    lazy_build => 1,
);
sub _build_digester { Digest->new('SHA-512') }
sub _digest_hex {
    my $d      = shift->digester;
    my $string = shift;
    $d->reset;
    $d->add( $string );
    return $d->hexdigest;
}

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
            username => {
                type     => 'Str',
                required => 1,
            },
            password => {
                type     => 'Str',
                required => 1,
                dependent => {
                    confirm_password => {
                        type     => 'Str',
                        required => 1,
                    }
                },
                post_check => sub {
                    my $r = shift;
                    $r->get_value('password') eq $r->get_value('confirm_password');
                }
            },
            permissions => {
                type => 'HashRef',
                coercion => Data::Verifier::coercion(
                    from => 'ArrayRef',
                    via  => sub { return { map { $_ => 1 } @$_ } }
                )
            }
        }
    );
    return { user => $verifier };
}


=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

no Moose;
__PACKAGE__->meta->make_immutable; 1;
