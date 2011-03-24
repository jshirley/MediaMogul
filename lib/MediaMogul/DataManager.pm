package MediaMogul::DataManager;

use Moose;

extends 'Data::Manager';

sub all_valids {
    my ( $self ) = @_;
    my $results = $self->results;

    map {
        my $r = $_;
        map { $_ => $r->get_value($_) }
        grep { defined $r->get_value($_) }
        $r->valids;
    } values %$results;
}

sub data_for_scope {
    my ( $self, $scope ) = @_;

    my $results = $self->get_results($scope);
    return {
        map  { $_ => $results->get_value($_) }
        grep { defined $results->get_value($_) }
        $results->valids
    };
};

sub unsuccessful_scopes {
    my ( $self ) = @_;
    my $results = $self->results || {};
    [ grep { not $results->{$_}->success } keys %$results ];
}

sub bad_fields {
    my ( $self ) = @_;
    my $results = $self->results || {};
    my $ret = {};
    foreach my $result ( keys %$results ) {
        next if $results->{$result}->success;
        $ret->{$result} = [
            $results->{$result}->invalids,
            $results->{$result}->missings
        ];
    }

    $ret;
}

sub new_from_classes {
    my ( $class, @classes ) = @_;
    
    my $verifiers = {};

    foreach my $class ( @classes ) {
        $verifiers = _extract_default_verification($class, $verifiers);
    }

    $class->new( verifiers => $verifiers );
}

sub _extract_default_verification {
    my ( $class, $profile ) = @_;

    Class::MOP::load_class($class);

    $profile ||= {};

    foreach my $attribute ( $class->meta->get_all_attributes ) {
        next unless $attribute->type_constraint eq 'HashRef[Data::Verifier]';
        my $verification;
        if ( my $def = $attribute->default ) {
            $verification = $def->();
        } elsif ( my $builder = $attribute->builder ) {
            $verification = $class->$builder();
        }
        $profile = { %$profile, %$verification };
    }

    return $profile;
}

no Moose;
__PACKAGE__->meta->make_immutable;

