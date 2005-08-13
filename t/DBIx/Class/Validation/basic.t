#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 45;
use Test::Exception;
use Test::NoWarnings;
use base qw(DBIx::Class::Validation);

my $class = __PACKAGE__;

ISA: {
    ok( UNIVERSAL::isa( $class, 'DBIx::Class::Validation' ),
        "$class is a DBIx::Class::Validation",
    );
}

LOAD_TYPES: {
    my $method = 'load_types';

    can_ok $class, $method;

    my $isa    = \our @ISA;
    my @expect = qw(DBIx::Class::Validation);

    is_deeply( $isa, \@expect, 'ISA contains only validation' );

    $class->$method(qw(number));

    push @expect, qw(DBIx::Class::Validation::Type::number);

    is_deeply( $isa, \@expect, 'ISA contains validation type classes' );

    dies_ok { $class->$method('croak') } 'cannot load non-existent types';
}

my $field;

GET_FIELD: {
    my $method = 'get_field';

    can_ok $class, $method;

    isa_ok $field = $class->$method('id'), $class . '::Field::id';
    is ref $field, $class . '::Field::id', 'correct object';
    is $field, $class->$method('id'), 'unique instance';

    dies_ok { $class->$method(undef) } 'must supply a field name';
}

my $field_name = $field->get_name;

SET_FIELD_COMMON: {
    my %attr = (
        label       => 'Test ID',
        description => 'a test identifier',
        default     => 1,
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

SET_FIELD_READ_ONLY: {
    my $method = 'set_field_read_only';

    can_ok $class, $method;

    is $field->get_is_read_only, 0, "$field_name is not read only";
    is $class->$method('id'),    0, "$field_name set to read only";
    is $field->get_is_read_only, 1, "$field_name is now read only";
}

SET_FIELD: {
    my $method = 'set_field';

    can_ok $class, $method;

    my %attr = (
        label       => 'Field',
        description => 'test',
        default     => 'a default value',
        read_only   => 1,
    );

    is(
        $class->$method( $field_name => \%attr ),
        undef,
        'set all fields',
    );

    while ( my ( $attr, $value ) = each %attr ) {
        my $accessor = $attr eq 'read_only' ? 'get_is_read_only'
                     :                        "get_$attr"
                     ;

        is $field->$accessor, $value, "field $attr is set";
    }
}

VALIDATES_PRESENCE_OF: {
    my $method = 'validates_presence_of';

    can_ok $class, $method;

    is(
        $class->$method( $field_name ),
        undef,
        "$method should be called in void context",
    );

    is $field->get_is_required, 1, "$field_name is now required";
}

VALIDATES_ALLOWED_VALUES_OF: {
    my $method = 'validates_allowed_values_of';

    can_ok $class, $method;

    my @allowed_values = qw(foo bar baz);

    is(
        $class->$method( $field_name => \@allowed_values ),
        undef,
        "$method should be called in void context",
    );

    is_deeply(
        $field->get_allowed_values,
        \@allowed_values,
        "$field_name has allowed values",
    );
}

VALIDATES_DISALLOWED_VALUES_OF: {
    my $method = 'validates_disallowed_values_of';

    can_ok $class, $method;

    my @disallowed_values = qw(fubar);

    is(
        $class->$method( $field_name => \@disallowed_values ),
        undef,
        "$method should be called in void context",
    );

    is_deeply(
        $field->get_disallowed_values,
        \@disallowed_values,
        "$field_name has disallowed values",
    );
}

VALIDATES_EACH_WITH: {
    my $method = 'validates_each_with';

    can_ok $class, $method;

    my @callbacks = ( sub { } );

    is(
        $class->$method( $field_name => \@callbacks ),
        undef,
        "$method should be called in void context",
    );

    is_deeply(
        $field->get_callbacks,
        \@callbacks,
        "$field_name has callbacks",
    );
}
