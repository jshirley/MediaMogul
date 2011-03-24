package MediaMogul::Base::Controller::REST::Mongo;

use Moose;
use Try::Tiny;

BEGIN { extends 'MediaMogul::Base::Controller::REST'; }

has 'class' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub _fetch_rs { return undef; }

sub root_POST { }

no Moose;
__PACKAGE__->meta->make_immutable;
