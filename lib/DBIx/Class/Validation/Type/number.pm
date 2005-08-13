package DBIx::Class::Validation::Type::number;

use strict;
use warnings FATAL => 'all';
use Carp qw( croak );
use DBIx::Class::Field::Type::number;
use Class::Std;
{
    sub validates_numericality_of : method {
        my ( $class, $field_name, $opt ) = @_;

        $class->_add_types_to_field($field_name => 'number');

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub validates_range_of : method {
        my ( $class, $field_name, $opt ) = @_;

        $class->validates_numericality_of($field_name);

        my $field = $class->get_field($field_name);

        foreach my $attr qw(min max) {
            my $value = $opt->{$attr};
            next if !defined $value;

            my $mutator = "set_${attr}_range";
            $field->$mutator($value);
        }

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub validates_precision_of : method {
        my ( $class, $field_name, $opt ) = @_;

        $class->validates_numericality_of($field_name);

        my $field = $class->get_field($field_name);

        foreach my $attr qw(min max) {
            my $value = $opt->{$attr};
            next if !defined $value;

            my $mutator = "set_${attr}_precision";
            $field->$mutator($value);
        }

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }
}

1;
