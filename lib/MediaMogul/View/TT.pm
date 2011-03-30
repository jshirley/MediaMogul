package MediaMogul::View::TT;

use Moose;

extends 'Catalyst::View::TT';

use Scalar::Util qw(blessed);
use DateTime;
use DateTimeX::Easy;
use Time::Duration qw(ago);

__PACKAGE__->config({
    render_die          => 1,
    PRE_CHOMP           => 1,
    POST_CHOMP          => 1,
    PRE_PROCESS         => 'site/shared/base.tt',
    WRAPPER             => 'site/wrapper.tt',
    TEMPLATE_EXTENSION  => '.tt',
    TIMER               => 0,
    static_root         => '/static',
    static_build        => 0,
    default_tz          => 'America/Los_Angeles',
    default_locale      => 'en_US',
    formats             => {
        date => {
            iso     => '%F',
            date    => '%x',
            short   => '%b %e, %G',
            medium  => '%b %e, %G %l:%M %p',
            long    => '%X %x',
            hour    => '%l:%M %p'
        }
    }
});

sub template_vars {
    my $self = shift;
    return (
        $self->next::method(@_),
        static_root  => $self->{static_root},
        static_build => $self->{static_build}
    );
}

sub new {
    my ( $class, $c, $arguments ) = @_;
    my $formats = $class->config->{formats};

    return $class->next::method( $c, $arguments ) unless ref $formats eq 'HASH';

    $class->config->{FILTERS} ||= {};

    my $filters = $class->config->{FILTERS};

    foreach my $key ( keys %$formats ) {
        if ( $key eq 'date' ) {
            foreach my $date_key ( keys %{$formats->{$key}} ) {
                $filters->{"${key}_$date_key"} = sub {
                    my $date = shift;
                    return unless defined $date;
                    unless ( blessed $date and $date->can("stringify") ) {
                        $date = DateTimeX::Easy->parse($date);
                        if ( $date->year < 1930 ) {
                            $date->add( years => 100 );
                        }
                    }
                    unless ( $date ) { return $date; }
                    $date->set_locale($class->config->{default_locale})
                        if defined $class->config->{default_locale};
                    # Only apply a timezone if we have a complete date.
                    unless ( "$date" =~ /T00:00:00$/ ) {
                        $date->set_time_zone( $class->config->{default_tz} || 'America/Los_Angeles' );
                    }
                    $date->strftime($formats->{$key}->{$date_key});
                };
            }
        }
        $filters->{'date_ago'} = sub {
            my $date = shift;
            return unless defined $date;
            unless ( blessed $date and $date->can("stringify") ) {
                $date = DateTimeX::Easy->new( parse => $date, time_zone_if_floating => 'UTC' );
                if ( $date->year < 1930 ) {
                    $date->add( years => 100 );
                }
            }
            unless ( $date ) { return $date; }
            $date->set_locale($class->config->{default_locale})
                if defined $class->config->{default_locale};
            # Only apply a timezone if we have a complete date.
            #unless ( "$date" =~ /T00:00:00$/ ) {
            $date = $date->set_time_zone( $class->config->{default_tz} || 'America/Los_Angeles' );
            my $now = DateTime->now;
            $now->set_time_zone( $class->config->{default_tz} || 'America/Los_Angeles' );
            ago($now->epoch - $date->epoch, 1);
        };
    }

    return $class->next::method( $c, $arguments );
}

1;
