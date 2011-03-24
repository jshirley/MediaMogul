package MediaMogul::Storage::Mongo;

use MooseX::Singleton;
use MongoDB;

use FindBin;
use Config::JFDI;
use Path::Class;

has 'host' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'localhost',
);

has 'port' => (
    is      => 'ro',
    isa     => 'Num',
    default => '27017',
);

has 'connection' => (
    is         => 'rw',
    isa        => 'MongoDB::Connection',
    lazy_build => 1,
    handles => {
        'get_database' => 'get_database'
    }
);

has 'database' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'mediamogul',
);

sub _build_connection {
    my ( $self ) = @_;

    my $dir = Path::Class::dir($FindBin::Bin);
    while ( $dir && !$dir->file('Makefile.PL')->stat ) {
        $dir = $dir->parent;
    }
    my $config = Config::JFDI->new( name => 'mediamogul', path => $dir)->get;
    $config = $config->{'Storage::Mongo'};

    MongoDB::Connection->new(
        host => $config->{host} || $self->host,
        port => $config->{port} || $self->port
    );
}

no MooseX::Singleton;
__PACKAGE__->meta->make_immutable;
