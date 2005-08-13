package DBIx::Class::Validation::Type::object;

use strict;
use warnings FATAL => 'all';
use Carp qw( croak );
use DBIx::Class::Field::Type::object;
use Class::Std;
{
    sub validates_roles_of : method {
        my ( $class, $field_name, $roles, $opt ) = @_;

        $class->_add_object_type_to_field($field_name);

        $class->get_field($field_name)->set_roles($roles);

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub validates_classes_of : method {
        my ( $class, $field_name, $classes, $opt ) = @_;

        $class->_add_object_type_to_field($field_name);

        $class->get_field($field_name)->set_classes($classes);

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub _add_object_type_to_field : PRIVATE method {
        my ( $class, $field_name, $opt ) = @_;

        my $field       = $class->get_field($field_name);
        my $field_class = ref $field;

        no strict 'refs';
        push @{"${field_class}::ISA"},
            grep { !$field->isa($_) }
            qw( DBIx::Class::Field::Type::object );

        return;
    }
}

1;
