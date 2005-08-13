#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 44;
use Test::NoWarnings;
use base qw(DBIx::Class::Field::Type::number);

my $class = __PACKAGE__;

my %attributes = ( name => 'number' );

my $obj;

NEW: {
    my $method = 'new';

    can_ok $class, $method;

    isa_ok $obj = $class->$method( \%attributes ), $class;
}

ATTRIBUTE_DEFAULTS: {
    my %attribute_defaults = (
        name          => $attributes{name},
        min_range     => -100**100**100,      # negative infinity
        max_range     =>  100**100**100,      # positive infinity
        min_precision => -100**100**100,      # negative infinity
        max_precision =>  100**100**100,      # positive infinity
    );

    while ( my ( $attr, $default ) = each %attribute_defaults ) {
        my $accessor = "get_$attr";            # Class::Std naming convention
        can_ok $obj, $accessor;
        is_deeply $obj->$accessor, $default, "default for $class->$accessor";
    }
}

ATTRIBUTES: {
    my %attributes = (
        name          => 'unit_price',
        label         => 'Unit Price',
        min_range     => 0,
        max_range     => 1000,
        min_precision => 2,
        max_precision => 2,
    );

    isa_ok $obj = $class->new( \%attributes ), $class;

    while ( my ( $attr, $default ) = each %attributes ) {
        my $accessor = "get_$attr";    # Class::Std naming convention
        can_ok $obj, $accessor;
        is_deeply $obj->$accessor, $default, "value for $class->$accessor";

        next if $attr eq 'name';

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

TYPE_OF: {
    my $method = 'type_of';

    can_ok $obj, $method;

    foreach my $type qw(number field) {
        my ($is_type) = $obj->$method($type);
        ok $is_type, "object is a type of $type";
    }
}
