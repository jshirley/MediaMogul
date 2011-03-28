package MediaMogul::Search;

use Moose;

use Data::SearchEngine::Query;
use Data::SearchEngine::Paginator;
use Data::SearchEngine::Results;
use Data::SearchEngine::Item;

use MediaMogul::Asset;

with 'Data::SearchEngine';

sub search {
    my ( $self, $query ) = @_;

    $query ||= {};
    if ( ref $query eq 'HASH' ) {
        $query = Data::SearchEngine::Query->new(
            page  => $query->{page} || 1,
            query => $query->{search} || '',
            count => $query->{count} || 20,
        );
    }

    # Get the cursor
    my $str    = $query->query;
    my $search = $str ? { name => qr/$str/ } : {};
    my $cursor = MediaMogul::Asset->query( $search );
    my $count  = $cursor->count(1);

    $cursor = $cursor->limit($query->count);
    if ( $query->page > 1 ) {
        $cursor = $cursor->skip( ($query->page - 1) * $query->count);
    }

    my $pager = Data::SearchEngine::Paginator->new(
        current_page     => $query->page,
        entries_per_page => $query->count,
        total_entries    => $count
    );

    my $result = Data::SearchEngine::Results->new(
        query => $query,
        pager => $pager
    );

    while ( my $row = $cursor->next ) {
        my %data = ();
        foreach my $key ( keys %$row ) {
            next if $key =~ /^_/;
            $data{$key} = $row->{$key};
        }

        $result->add(
            Data::SearchEngine::Item->new(
                values => \%data,
                score  => 1
            )
        );
    }
    
    return $result;
}

no Moose;
__PACKAGE__->meta->make_immutable; 1;
