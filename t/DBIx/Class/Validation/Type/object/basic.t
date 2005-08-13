#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 14;
use Test::Exception;
use Test::NoWarnings;
use base qw(DBIx::Class::Validation);

BEGIN {
    __PACKAGE__->load_types('object');
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
my $object_type = 'DBIx::Class::Field::Type::object';

isa_ok $field, $class .'::Field::id';

VALIDATES: {
    my %attr = (
        roles   => [ qw( foo bar baz ) ],
        classes => [ qw( Foo Bar Baz ) ],
    );

    ok(
        !$field->isa($object_type),
        "$field_name is not a type of object",
    );

    while ( my($attr, $value) = each %attr) {
        my $method = "validates_${attr}_of";

        is(
            $class->$method( $field_name => $value ),
            undef,
            "$method should be called in void context",
        );

        my $accessor = "get_${attr}";

        is_deeply(
            $field->$accessor,
            $value,
            "$field_name has a correct value for $attr",
        );

        # field type has now been changed to object
        isa_ok $field, $object_type;
        is $field->type_of('object'), 1, "$field_name is a object type";
        is $field->type_of('field'),  1, "$field_name is a field type";
    }
}
