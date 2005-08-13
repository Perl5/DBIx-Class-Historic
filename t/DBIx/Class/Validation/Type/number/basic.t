#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 25;
use Test::Exception;
use Test::NoWarnings;
use base qw(DBIx::Class::Validation);

BEGIN {
    __PACKAGE__->load_types('number');
}

my $class = __PACKAGE__;

ISA: {
    ok(
        UNIVERSAL::isa( $class, 'DBIx::Class::Validation' ),
        "$class is a DBIx::Class::Validation",
    );
}

my $field      = My::Test->get_field('id');
my $field_name = $field->get_name;

isa_ok $field, $class .'::Field::id';

VALIDATES_NUMERICALITY_OF: {
    my $method = 'validates_numericality_of';

    can_ok $class, $method;

    my $number_type = 'DBIx::Class::Field::Type::number';

    ok(
        !$field->isa($number_type),
        "$field_name is not a type of number",
    );

    is(
        $class->$method( $field_name ),
        undef,
        "$method should be called in void context",
    );

    isa_ok $field, $number_type;

    is $field->type_of('number'), 1, "$field_name is a number type";
    is $field->type_of('field'),  1, "$field_name is a field type";
}

VALIDATES_RANGE_OF: {
    my $method = 'validates_range_of';

    can_ok $class, $method;

    my %opt = (
        min => 1,
        max => 40,
    );

    my %change = (
        min => 10,
        max => 20,
    );

    is(
        $class->$method($field_name => \%opt),
        undef,
        "$method should be called in void context",
    );

    foreach my $key (keys %opt) {
        my $accessor = "get_${key}_range";
        is(
            $field->$accessor,
            $opt{$key},
            "$field_name $key range is set",
        );

        is(
            $class->$method($field_name => { $key => $change{$key} }),
            undef,
            "$method should be called in void context",
        );

        is(
            $field->$accessor,
            $change{$key},
            "$field_name $key range is changed",
        );
    }
}

VALIDATES_PRECISION_OF: {
    my $method = 'validates_precision_of';

    can_ok $class, $method;

    my %opt = (
        min => 1,
        max => 3,
    );

    my %change = (
        min => 2,
        max => 4,
    );

    is(
        $class->$method($field_name => \%opt),
        undef,
        "$method should be called in void context",
    );

    foreach my $key (keys %opt) {
        my $accessor = "get_${key}_precision";
        is(
            $field->$accessor,
            $opt{$key},
            "$field_name $key precision is set",
        );

        is(
            $class->$method($field_name => { $key => $change{$key} }),
            undef,
            "$method should be called in void context",
        );

        is(
            $field->$accessor,
            $change{$key},
            "$field_name $key precision is changed",
        );
    }
}
