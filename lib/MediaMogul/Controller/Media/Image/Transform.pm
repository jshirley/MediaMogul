package MediaMogul::Controller::Media::Image::Transform;

use Moose;

BEGIN { extends 'Catalyst::Controller'; }

sub setup : Chained('.') PathPart('transform') CaptureArgs(0) { }

sub root : Chained('setup') PathPart('') Args(0) { 
    my ( $self, $c ) = @_;

    foreach my $p ( keys %{ $c->req->params } ) {
        my $action = $c->controller->action_for($p);
        next unless defined $action;

        my $args = $c->req->params->{$p};
        my @bits = split(',', $args);
        my %opts = map {
                        my ( $key, $value ) = split(':', $_);
                        $key => $value
                    } grep { /^([A-Za-z]+):(\w+)$/ } @bits;

        $c->forward($action, [ \%opts ]);
    }
    my $image = $c->stash->{image};
    my $data;
    my $type = MIME::Types->new->type($c->res->content_type);
    $image->write(
        data => \$data,
        type => $type->subType
    ) or $c->log->error($image->errstr);
    $c->res->body( $data );
}

sub rotate : Private {
    my ( $self, $c, $opts ) = @_;

    my $image = $c->stash->{image};
    $c->stash->{image} = $image->rotate( %$opts );
}

sub scale : Private {
    my ( $self, $c, $opts ) = @_;
    my $image = $c->stash->{image};
    if ( my $y = $opts->{ypixels} and my $x = $opts->{xpixels} ) {
        if ( $y > $image->getwidth and $x > $image->getwidth ) {
            # Don't do anything if we're already too big.
            return;
        }
    }
    $c->stash->{image} = $image->scale( %$opts );
}

sub flip : Private { }

no Moose;
__PACKAGE__->meta->make_immutable; 1;
