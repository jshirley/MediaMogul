package MediaMogul::Model::DataManager;

use Moose;
use Try::Tiny;

use MediaMogul::DataManager;

extends 'Catalyst::Model';

with 'Catalyst::Component::InstancePerContext';
sub build_per_context_instance {
    my ( $self, $c ) = @_;

    my $dm = MediaMogul::DataManager->new_from_classes(
        'MediaMogul::Asset',
        'MediaMogul::User',
        'MediaMogul::Profile',
    );

    $dm;
}

no Moose;
__PACKAGE__->meta->make_immutable;

