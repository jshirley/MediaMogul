package MediaMogul::Model::Search;

use Moose;

use MediaMogul::Search;

with 'Catalyst::Component::InstancePerContext';

sub build_per_context_instance {
    MediaMogul::Search->new;
}

no Moose;
__PACKAGE__->meta->make_immutable; 1;
