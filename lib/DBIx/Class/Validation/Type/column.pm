package DBIx::Class::Validation::Type::column;

use strict;
use warnings FATAL => 'all';
use base qw( DBIx::Class::Validation );
use Carp qw( croak );
use DBIx::Class::Field::Type::column;
use Class::Std;
{
    sub set_field_column_name : RESTRICTED method {
        my ( $class, $field_name, $column_name ) = @_;

        $class->_add_column_type_to_field($field_name);

        return shift->get_field($field_name)->set_column_name($column_name);
    }

    sub set_field_inflate : RESTRICTED method {
        my ( $class, $field_name, $column_name ) = @_;

        $class->_add_column_type_to_field($field_name);

        return shift->get_field($field_name)->set_inflate($column_name);
    }

    sub set_field_deflate : RESTRICTED method {
        my ( $class, $field_name, $column_name ) = @_;

        $class->_add_column_type_to_field($field_name);

        return shift->get_field($field_name)->set_deflate($column_name);
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
