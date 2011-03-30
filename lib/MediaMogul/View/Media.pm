package MediaMogul::View::Media;

use strict;
use warnings;

use base 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    INCLUDE_PATH       => [
        MediaMogul->path_to('root/templates'),
        MediaMogul->path_to('templates'),
    ],
    render_die         => 1,
);

=head1 NAME

MediaMogul::View::Media - TT View for MediaMogul

=head1 DESCRIPTION

TT View for MediaMogul.

=head1 SEE ALSO

L<MediaMogul>

=head1 AUTHOR

Jay Shirley

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
