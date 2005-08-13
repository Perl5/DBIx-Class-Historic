package DBIx::Class::Validation::Type::column;

use strict;
use warnings FATAL => 'all';
use Carp qw( croak );
use DBIx::Class::Field::Type::column;
use Class::Std;
{
    sub set_field_column_name : method {
        my ( $class, $field_name, $column_name ) = @_;

        $class->_add_column_type_to_field($field_name);

        return shift->get_field($field_name)->set_column_name($column_name);
    }

    sub _add_column_type_to_field : PRIVATE method {
        my ( $class, $field_name, $opt ) = @_;

        my $field       = $class->get_field($field_name);
        my $field_class = ref $field;

        no strict 'refs';
        push @{"${field_class}::ISA"},
            grep { !$field->isa($_) }
            qw( DBIx::Class::Field::Type::column );

        return;
    }
}

1;
