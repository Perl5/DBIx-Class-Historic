#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 48;
use Test::NoWarnings;
use base qw(DBIx::Class::Field::Type::string);

my $class = __PACKAGE__;

my %attributes = ( name => 'string' );

my $obj;

NEW: {
    my $method = 'new';

    can_ok $class, $method;

    isa_ok $obj = $class->$method( \%attributes ), $class;
}

ATTRIBUTE_DEFAULTS: {
    my %attribute_defaults = (
        name             => $attributes{name},
        min_length       => -100**100**100,
        max_length       =>  100**100**100,
        allowed_chars    => [],
        disallowed_chars => [],
        format           => qr//,
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

ATTRIBUTES: {
    my %attributes = (
        name             => 'first_name',
        label            => 'First Name',
        min_length       => 1,
        max_length       => 40,
        allowed_chars    => [ 'A' .. 'Z', 'a' .. 'z' ],
        disallowed_chars => [ 'q'                    ],
        format           => qr/\A[A-Z][a-z]+\z/,          # its just a test!
    );

    isa_ok $obj = $class->new( \%attributes ), $class;

    while ( my ( $attr, $default ) = each %attributes ) {
        my $accessor = "get_$attr";    # Class::Std naming convention
        can_ok $obj, $accessor;
        is_deeply $obj->$accessor, $default, "value for $class->$accessor";
    }
}

TYPE_OF: {
    my $method = 'type_of';

    can_ok $obj, $method;

    foreach my $type qw(string field) {
        my ($is_type) = $obj->$method($type);
        ok $is_type, "object is a type of $type";
    }
}
