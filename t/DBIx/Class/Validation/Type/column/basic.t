#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 15;
use Test::Exception;
use Test::NoWarnings;
use base qw(DBIx::Class::Validation);

BEGIN {
    __PACKAGE__->load_types('column');
}

my $class = __PACKAGE__;

ISA: {
    ok(
        UNIVERSAL::isa( $class, 'DBIx::Class::Validation' ),
        "$class is a DBIx::Class::Validation",
    );
}

my $field       = My::Test->get_field('id');
my $field_name  = $field->get_name;
my $column_type = 'DBIx::Class::Field::Type::column';

isa_ok $field, $class .'::Field::id';

SET_FIELD_COMMON: {
    my %attr = (
        column_name => 'Test ID',
        deflate     => [],
        inflate     => [],
    );

    while ( my ( $attr, $value ) = each %attr ) {
        my $mutator = "set_field_$attr";

        can_ok $class, $mutator;
        is(
            $class->$mutator( $field_name => $value ),
            undef,
            "set field $attr",
        );

        my $accessor = "get_$attr";
        is $field->$accessor, $value, "get field $attr";

        # returns the previous value on-set
        is(
            $class->$mutator( $field_name => $value ),
            $value,
            "set field $attr",
        );
    }
}
