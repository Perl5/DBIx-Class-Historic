package DBIx::Class::Field::Type::column;

use version; our $VERSION = qv('0.2.0');

use strict;
use warnings FATAL => 'all';
use base qw(DBIx::Class::Field);
use Class::Std;
{
    my %table_of       : ATTR( :init_arg<table>       :get<table>       :set<table>                       );
    my %column_name_of : ATTR( :init_arg<column_name> :get<column_name> :set<column_name> :default<undef> );
    my %deflate_with   : ATTR( :init_arg<deflate>     :get<deflate>     :set<deflate>     :default<undef> );
    my %inflate_with   : ATTR( :init_arg<inflate>     :get<inflate>     :set<inflate>     :default<undef> );

    sub BUILD : method {
        my ( $self, $ident, $arg_ref ) = @_;

        # if the column name is not provided set it to the field name
        $column_name_of{$ident}
            = defined $arg_ref->{column_name} ? $arg_ref->{column_name}
            :                                   $self->get_name
            ;

        return;
    }

    sub types : CUMULATIVE method { 'column' }

}

1;
