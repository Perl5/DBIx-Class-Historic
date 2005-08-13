package DBIx::Class::Validation::Type::string;

use strict;
use warnings FATAL => 'all';
use base qw( DBIx::Class::Validation );
use Carp qw( croak );
use DBIx::Class::Field::Type::string;
use Class::Std;
{
    sub validates_length_of : RESTRICTED method {
        my ( $class, $field_name, $opt ) = @_;

        $class->_add_string_type_to_field($field_name);

        my $field = $class->get_field($field_name);

        foreach my $attr qw(min max) {
            my $value = $opt->{$attr};
            next if !defined $value;

            my $mutator = "set_${attr}_length";
            $field->$mutator($value);
        }

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub validates_allowed_chars_of : RESTRICTED method {
        my ( $class, $field_name, $allowed_chars, $opt ) = @_;

        $class->_add_string_type_to_field($field_name);

        $class->get_field($field_name)
              ->set_allowed_chars($allowed_chars);

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub validates_disallowed_chars_of : RESTRICTED method {
        my ( $class, $field_name, $disallowed_chars, $opt ) = @_;

        $class->_add_string_type_to_field($field_name);

        $class->get_field($field_name)
              ->set_disallowed_chars($disallowed_chars);

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub validates_format_of : RESTRICTED method {
        my ( $class, $field_name, $format, $opt ) = @_;

        $class->_add_string_type_to_field($field_name);

        $class->get_field($field_name)
              ->set_format($format);

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub _add_string_type_to_field : PRIVATE method {
        my ( $class, $field_name, $opt ) = @_;

        my $field       = $class->get_field($field_name);
        my $field_class = ref $field;

        no strict 'refs';
        push @{"${field_class}::ISA"},
            grep { !$field->isa($_) }
            qw( DBIx::Class::Field::Type::string );

        return;
    }
}

1;
