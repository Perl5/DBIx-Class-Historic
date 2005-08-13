#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 23;
use Test::NoWarnings;
use base qw(DBIx::Class::Field::Type::object);

my $class = __PACKAGE__;

my %attributes = ( name => 'vehicle' );

my $obj;

NEW: {
    my $method = 'new';

    can_ok $class, $method;

    isa_ok $obj = $class->$method( \%attributes ), $class;
}

ATTRIBUTE_DEFAULTS: {
    my %attribute_defaults = (
        roles   => [],
        classes => [],
    );

    while ( my ( $attr, $default ) = each %attribute_defaults ) {
        my $accessor = "get_$attr";    # Class::Std naming convention
        can_ok $obj, $accessor;
        is_deeply $obj->$accessor, $default, "default for $class->$accessor";

        my $mutator = "set_$attr";     # Class::Std naming convention
        can_ok $obj, $mutator;

        is_deeply(
            $obj->$mutator(undef),     # explicitly set to undef
            $default,                  # returns the previous value
            "previous value $class->$mutator",
        );

        is $obj->$accessor, undef, 'value is now undef';
    }
}

ATTRIBUTES: {
    my %attributes = (
        %attributes,
        roles   => [ qw( steer brake gas four_wheel_drive ) ],
        classes => [ qw( Vehicle Jeep                     ) ],
    );

    isa_ok $obj = $class->new( \%attributes ), $class;

    while ( my ( $attr, $default ) = each %attributes ) {
        my $accessor = "get_$attr";    # Class::Std naming convention
        can_ok $obj, $accessor;
        is_deeply $obj->$accessor, $default, "default for $class->$accessor";
    }
}

TYPE_OF: {
    my $method = 'type_of';

    can_ok $obj, $method;

    foreach my $type qw(object field) {
        my ($is_type) = $obj->$method($type);
        ok $is_type, "object is a type of $type";
    }
}
