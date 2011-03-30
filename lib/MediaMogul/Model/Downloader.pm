package MediaMogul::Model::Downloader;

use Moose;

use HTTP::Request;
use LWP::UserAgent;
use LWP::MediaTypes qw(guess_media_type media_suffix);

use File::Temp qw/:seekable tempfile/;
use Catalyst::Request::Upload;

extends 'Catalyst::Model';

has 'ua' => (
    is      => 'ro',
    isa     => 'LWP::UserAgent',
    lazy    => 1,
    default => sub {
        LWP::UserAgent->new(
            agent       => "MediaMogul/$MediaMogul::VERSION",
            keep_alive  => 0,
            env_proxy   => 1,
        )
    }
);

sub get {
    my ( $self, $url ) = @_;

    local $| = 1;

    $url = URI->new($url, 'http');
    
    my $res = $self->ua->get( $url );
    die $res unless $res->is_success;

    my ( $fh, $tempname ) = tempfile();

    my $filename = $res->filename;

    if ( not $filename ) {
        $filename = ($url->path_segments)[-1];
        if ( not defined $filename or not length $filename ) {
            $filename = "index";
            my $suffix = media_suffix($res->content_type);
            $filename .= ".$suffix" if $suffix;
        }
        # Helpfully borrowed from lwp-download
        if ( not length($filename) ||
            $filename =~ s/([^a-zA-Z0-9_\.\-\+\~])/sprintf "\\x%02x", ord($1)/ge ||
            $filename =~ /^\./
        ) {
            die "Will not save <$url> as \"$filename\".\n";
        }
    }
    warn "Final filename: $filename\n";
    binmode $fh;
    my $length  = $res->content_length;

    print $fh $res->content;

    $fh->close;

    return Catalyst::Request::Upload->new(
        tempname => $tempname,
        headers  => $res->headers,
        size     => $length,
        type     => $res->content_type,
        filename => $filename,
    );
}

no Moose;
__PACKAGE__->meta->make_immutable;
