package MediaMogul::Controller::Media::Image;

use Moose;
use Imager;

BEGIN { extends 'Catalyst::Controller'; }

sub setup : Chained('.') PathPart('image') CaptureArgs(0) { 
    my ( $self, $c ) = @_;
    my $file = $c->stash->{asset}->get_file;
    # Setup the data from imager.

    my $image = Imager->new( data => $file->slurp );

    if ( not defined $image ) {
        $c->res->status(400);
        $c->res->body($c->loc("Media says it is an image, but fails to be parsed as one."));
        $c->detach;
    }
    $c->res->content_type( $file->info->{content_type} );
    $c->stash->{image} = $image;
}

sub transform : Chained('setup') PathPart('') CaptureArgs(0) { }

no Moose;
__PACKAGE__->meta->make_immutable; 1;
