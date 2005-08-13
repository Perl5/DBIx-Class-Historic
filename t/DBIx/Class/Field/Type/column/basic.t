#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 166;
use Test::NoWarnings;
use base qw(DBIx::Class::Field::Type::column);

my $class = __PACKAGE__;

my %attributes = (
    name  => 'customer_id',
    table => 'customer',
);

my $obj;

NEW: {
    my $method = 'new';

    can_ok $class, $method;

    isa_ok $obj = $class->$method( \%attributes ), $class;
}

ATTRIBUTE_DEFAULTS: {
    my %attribute_defaults = (
        name        => $attributes{name},
        table       => $attributes{table},
        column_name => $attributes{name},
        inflate     => undef,
        deflate     => undef,
    );

    while ( my ( $attr, $default ) = each %attribute_defaults ) {
        my $accessor = "get_$attr";    # Class::Std naming convention
        can_ok $obj, $accessor;
        is_deeply $obj->$accessor, $default, "default for $class->$accessor";

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

my %with_inflate_deflate = (
    %attributes,
    inflate => sub { pop() },
    deflate => sub { pop() },
);

isa_ok $obj = $class->new( \%with_inflate_deflate ), $class;

DEFLATE: {
    my $method = 'get_deflate';

    can_ok $obj, $method;

    is ref $obj->$method, 'CODE', 'is a subref';

    foreach my $value ( 'A' .. 'Z', 'a' .. 'z', 0 .. 10 ) {
        my $deflated = $obj->$method->($value);
        is $deflated, $value, "should pass-through value $value";
    }
}

INFLATE: {
    my $method = 'get_inflate';

    can_ok $obj, $method;

    is ref $obj->$method, 'CODE', 'is a subref';

    foreach my $value ( 'A' .. 'Z', 'a' .. 'z', 0 .. 10 ) {
        my $inflated = $obj->$method->($value);
        is $inflated, $value, "should pass-through value $value";
    }
}

TYPE_OF: {
    my $method = 'type_of';

    can_ok $obj, $method;

    foreach my $type qw(column field) {
        my ($is_type) = $obj->$method($type);
        ok $is_type, "object is a type of $type";
    }
}

ATTRIBUTES: {
    my %attributes = ( %attributes, column_name => 'id' );

    isa_ok $obj = $class->new( \%attributes ), $class;

    while ( my ( $attr, $default ) = each %attributes ) {
        my $accessor = "get_$attr";    # Class::Std naming convention
        can_ok $obj, $accessor;
        is_deeply $obj->$accessor, $default, "default for $class->$accessor";
    }
}
