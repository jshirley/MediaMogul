package MediaMogul::Controller::Admin;

use Moose;

BEGIN { extends 'MediaMogul::Base::Controller::REST::Mongo'; }

use Scalar::Util 'blessed';
use Hash::Diff qw(left_diff);

use URI::Escape;

__PACKAGE__->config(
    actions       => { 'setup' => { PathPart => 'admin' } },
    class         => 'Asset',
    create_string => 'The media has been uploaded with the key [_2].',
    update_string => 'The media [_1] has been updated.',
    error_string  => 'There was an error processing the update to your media, please try again.',
    scope => 'admin',
    allow_by_default => 0,
    object_key => 'admin',
    permissions => {
        'setup' => [ '@admin' ],
    }
);

sub root_GET { }
sub root_POST { }

sub manage_form : Chained('setup') PathPart('manage') Args(0) { }

sub profile : Chained('setup') PathPart('') CaptureArgs('0') { }

no Moose;
__PACKAGE__->meta->make_immutable; 1;
