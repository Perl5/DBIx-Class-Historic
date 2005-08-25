#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 46;
use Test::Exception;
use Test::NoWarnings;
use base qw(DBIx::Class::Field);

my $class = __PACKAGE__;

my $obj;

NEW: {
    my $method = 'new';

    can_ok $class, $method;

    isa_ok $obj = $class->$method( { name => 'id' } ), $class;
}

ATTRIBUTE_DEFAULTS: {
    my %attribute_defaults = (
        label             => 'Id',
        description       => undef,
        allowed_values    => [],
        callbacks         => [],
        disallowed_values => [],
        is_read_only      => 0,
        is_required       => 0,
        default           => undef,
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

TYPE_OF: {
    my $method = 'type_of';

    can_ok $obj, $method;

    my ($is_field) = $obj->$method('field');
    ok $is_field, 'object is a type of field';

    my ($is_thingy) = $obj->$method('thingy');
    ok !$is_thingy, 'object is not a type of thingy';
}
