package MooseX::Storage::IO::Mongo;

use Moose::Role;
use Scalar::Util 'blessed';
use Try::Tiny;

use MongoDB::OID;

use MediaMogul::Storage::Mongo;

our $VERSION = '0.01';

requires 'thaw';
requires 'freeze';

has '_id' => (
    is        => 'rw',
    isa       => 'MongoDB::OID',
    predicate => 'has_mongo_id',
    traits    => [ 'DoNotSerialize' ]
);

sub delete {
    my ( $self ) = @_;

    my $col = $self->_get_mongo_collection;
    $col->remove({ _id => $self->_id });
}

sub _get_mongo_database {
    my $mongo = MediaMogul::Storage::Mongo->instance;
    return $mongo->get_database($mongo->database);
}

sub get_next_sequence {
    my ( $self ) = @_;

    my $mongo = MediaMogul::Storage::Mongo->instance;
    my $db    = $mongo->get_database($mongo->database);
    my $col   = $db->get_collection( 'sequences' );
    my $cname = $self->_get_mongo_collection_name;

    # If only findAndModify actually worked! :(
    # Look at ::Organization for sequences scoped into an organization as
    # an embedded document, more elegant anyway
    my $command = $col->run_command({
            findAndModify => 'sequences',
            query  => { _id => $cname },
            update => { '$inc' => { 'seq' => 1 } },
            'new'  => 1
    });

    return $command;
}

sub _get_mongo_collection_name {
    my $self = shift;

    my $class = $self;
    if ( ref $class ) {
        $class = $self->meta->name;
        if ( $class =~ /^MooseX::Traits/ or $class =~ /^Class::MOP::Class::__ANON__/ ) {
            ( $class) = $self->meta->superclasses;
        }
    }
    my ( $c_name ) = $class;
        $c_name =~ s{([a-z])([A-Z])}{$1_$2}g;
        $c_name =~ s{\:\:}{_}g;
        $c_name = lc($c_name);
    return $c_name;
}

sub _get_mongo_collection {
    my $self = shift;

    my $mongo = MediaMogul::Storage::Mongo->instance;
    my $db   = $mongo->get_database($mongo->database);
    return $db->get_collection( $self->_get_mongo_collection_name );
}

sub load {
    my ( $self, $id, @args ) = @_;
    if ( blessed $self and $self->_id ) {
        return $self->load( $self->_id );
    }

    unless ( blessed $id and $id->isa('MongoDB::OID') ) {
        $id = MongoDB::OID->new( value => "$id" );
    }
    
    $self->find_one({ _id => $id });
}

sub store {
    my ( $self, $id, @args ) = @_;
    my $data = $self->freeze;
    my $col  = $self->_get_mongo_collection;
    return $self->_store( $id, $data, $col );
}

sub _store {
    my ( $self, $id, $data, $col ) = @_;
    # Update
    if ( $self->has_mongo_id ) {
        $id = $self->_id;
        $col->update({ '_id' => $self->_id }, $data, { safe => 1, upsert => 1 } );
    } else {
        $id = $col->insert( $data );
        $self->_id( $id );
    } 

    return $id;
}

sub archive {
    my ( $self, $id, @args ) = @_;
    my $data     = $self->freeze;

    my $mongo    = MediaMogul::Storage::Mongo->instance;
    my $db       = $mongo->get_database($mongo->database);

    my $col_name = $self->_get_mongo_collection_name . '_archive';
    my $col      = $db->get_collection( $col_name );

    $id = $self->_store( $id, $data, $col );
    if ( $id ) {
        # Remove from the old non-archived collection
        $self->delete;
    }
    return $id;
}

sub load_archived {
    my ( $self, $id, @args ) = @_;

    unless ( blessed $id and $id->isa('MongoDB::OID') ) {
        $id = MongoDB::OID->new( value => "$id" );
    }
    
    my $mongo    = MediaMogul::Storage::Mongo->instance;
    my $db       = $mongo->get_database($mongo->database);

    my $col_name = $self->_get_mongo_collection_name . '_archive';
    my $col      = $db->get_collection( $col_name );

    my $result   = $col->find_one({ _id => $id });

    if ( defined $result ) {
        return $self->thaw( $result );
    }
    return undef;

}

sub find_one {
    my ( $self, $query ) = @_;

    my $col  = $self->_get_mongo_collection;
    my $result = $col->find_one( $query );

    if ( defined $result ) {
        return $self->thaw($result);
    }
    return undef;
}

sub find {
    my ( $self, $query ) = @_;

    my $col     = $self->_get_mongo_collection;
    my $results = $col->find( $query );
    my @final   = ();
    foreach my $config ( $results->all ) {
        try { push @final, $self->thaw($config); }
        catch { warn "Unable to inflate asset: $_"; };
    }
    
    return @final;
}

no Moose::Role;
1;
