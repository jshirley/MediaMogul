package MooseX::Storage::Format::Moose;

use Moose::Role;

use Moose::Meta::Class;
use MooseX::Traits::Util;

use Try::Tiny;

use DateTime;

MooseX::Storage::Engine->add_custom_type_handler(
    'DateTime' => (
        expand   => sub { DateTime->from_epoch(shift) },
        collapse => sub { (shift)->epoch },
    )
);

MooseX::Storage::Engine->add_custom_type_handler(
    'MongoDB::OID' => (
        expand   => sub { MongoDB::OID->new( value => shift ); },
        collapse => sub { shift->to_string }
    )
);

MooseX::Storage::Engine->add_custom_type_handler(
    'ArrayRef[MongoDB::OID]' => (
        expand   => sub {
            my $list = shift;
            [ map { MongoDB::OID->new( value => $_ ); } @$list ]
        },
        collapse => sub {
            my $list = shift;
            [ map { $_->to_string } @$list ]
        }
    )
);

no warnings 'once';
use utf8 ();

our $VERSION = '0.01';

sub thaw {
    my ( $class, $doc, %args ) = @_;

    my $obj = undef;
    if ( $doc->{traits} and $doc->{_trait_namespace} ) {
        delete $doc->{_trait_namespace};
        my @traits = ref $doc->{traits} ? @{$doc->{traits}} : ($doc->{traits});
        # Ignore traits like:
        # Jarvis::Asset::Something|Jarvis::Asset::SomethingElse since we
        # should have caught those in freeze.
        @traits = grep { !/\|/; } @traits;

        my $meta = Moose::Meta::Class->create_anon_class(
            superclasses => [ $class ],
            roles        => [ MooseX::Traits::Util::resolve_traits($class, @traits) ],
            cache        => 1
        );
        my $e = $class->_storage_get_engine_class(%args)->new(class => $meta->name);
        $obj = MooseX::Storage::Basic::_storage_construct_instance(
            $meta->name,
            $e->expand_object($doc, %args),
            \%args
        );
    } else {
        $obj = $class->unpack( $doc, %args );
    }

    $obj->_id( $doc->{_id} ) if defined $obj;
    return $obj;
}

sub freeze {
    my ( $self, @args ) = @_;

    my $raw = $self->pack( @args );
    # Now, we look at the traits on the class. If it does MooseX::Traits we
    # look at the anon class and pull out any role that has ^Jarvis in it, and
    # add it to __TRAITS__
    if ( $self->meta->does_role('MooseX::Traits') and ( ref $self ) =~ /^MooseX::Traits/ ) { 
        # XX Support multiple classes?
        ( $raw->{__CLASS__} ) = $self->meta->superclasses;
        $raw->{traits} = [
            map { '+' . $_->name }
            grep { !$_->is_anon_role }
            $self->meta->calculate_all_roles
        ];
    }

    return $raw;
}

no Moose::Role;
1;
