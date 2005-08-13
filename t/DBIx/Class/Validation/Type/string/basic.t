#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 21;
use Test::Exception;
use Test::NoWarnings;
use base qw(DBIx::Class::Validation);

BEGIN {
    __PACKAGE__->load_types('string');
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
my $string_type = 'DBIx::Class::Field::Type::string';

isa_ok $field, $class .'::Field::id';

VALIDATES_LENGTH_OF: {
    my $method = 'validates_length_of';

    can_ok $class, $method;

    my %opt = (
        min => 1,
        max => 40,
    );

    my %change = (
        min => 10,
        max => 20,
    );

    ok(
        !$field->isa($string_type),
        "$field_name is not a type of string",
    );

    is(
        $class->$method($field_name => \%opt),
        undef,
        "$method should be called in void context",
    );

    # field type has now been changed to string
    isa_ok $field, $string_type;
    is $field->type_of('string'), 1, "$field_name is a string type";
    is $field->type_of('field'),  1, "$field_name is a field type";

    foreach my $key (keys %opt) {
        my $accessor = "get_${key}_length";
        is(
            $field->$accessor,
            $opt{$key},
            "$field_name $key length is set",
        );

        is(
            $class->$method($field_name => { $key => $change{$key} }),
            undef,
            "$method should be called in void context",
        );

        is(
            $field->$accessor,
            $change{$key},
            "$field_name $key length is changed",
        );
    }
}

VALIDATES: {
    my %attr = (
        allowed_chars    => [ qw( a b c d e ) ],
        disallowed_chars => [ qw( f g h i j ) ],
        format           => qr/.*/,
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
    }
}
