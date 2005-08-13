package DBIx::Class::Validation::Type::column;

use strict;
use warnings FATAL => 'all';
use Carp qw( croak );
use DBIx::Class::Field::Type::column;
use Class::Std;
{
    sub set_field_column_name : method {
        my ( $class, $field_name, $column_name ) = @_;

        $class->_add_types_to_field($field_name => 'column');

        return shift->get_field($field_name)->set_column_name($column_name);
    }
}

1;
