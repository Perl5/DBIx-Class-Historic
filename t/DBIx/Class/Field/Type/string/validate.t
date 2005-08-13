#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 54;
use Test::NoWarnings;
use base qw(DBIx::Class::Field::Type::string);

my $class = __PACKAGE__;

my %attributes = (
    name             => 'first_name',
    label            => 'First Name',
    min_length       => 1,
    max_length       => 40,
    allowed_chars    => [ 'A' .. 'Y', 'a' .. 'y' ],
    disallowed_chars => [ 'q'                    ],
    format           => qr/\A(?:[A-Z][a-z]*)?\z/,     # its just a test!
);

my $obj;

NEW: {
    my $method = 'new';

    can_ok $class, $method;

    isa_ok $obj = $class->$method( \%attributes ), $class;
}

ATTRIBUTES: {
    while ( my ( $attr, $value ) = each %attributes ) {
        next if $attr eq 'callbacks';

        my $accessor = "get_$attr";    # Class::Std naming convention
        can_ok $obj, $accessor;
        is_deeply $obj->$accessor, $value, "value for $class->$accessor";
    }
}

VALIDATE: {
    my $method = 'validate';

    can_ok $obj, $method;

    my $first_name = 'Dan';

    my @results = $obj->$method($first_name);
    is_deeply \@results, [], "$first_name is a valid " . $obj->get_label;
}

VALIDATE_IS_STRING: {
    my $method = 'validate_is_string';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error( is_string => 'is not a string' );

    my $hash_ref = {};

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($hash_ref) ],
            [ $error                   ],
            "$hash_ref is invalid, " . $obj->get_label . ' must be a string',
        );

        is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    }
}

VALIDATE_MIN_LENGTH: {
    my $method = 'validate_min_length';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error( min_length => 'is too short' );

    my $first_name = '';

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($first_name) ],
            [ $error                     ],
            "$first_name is too short of a value for " . $obj->get_label,
        );
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method( {} )  ], [], 'handles non-string';
}

VALIDATE_MAX_LENGTH: {
    my $method = 'validate_max_length';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error( max_length => 'is too long' );

    my $first_name = 'A' . 'a' x 40;

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($first_name) ],
            [ $error                     ],
            "$first_name is too long of a value for " . $obj->get_label,
        );
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method( {} )  ], [], 'handles non-string';
}

VALIDATE_ALLOWED_CHARS: {
    my $method = 'validate_allowed_chars';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error(
        allowed_chars => 'contains characters that are not allowed',
        [ 'Z' ],
    );

    my $first_name = 'Zoltan';

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($first_name) ],
            [ $error                     ],
            "$first_name constains invalid characters for " . $obj->get_label,
        );
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method( {} )  ], [], 'handles non-string';
}

VALIDATE_DISALLOWED_CHARS: {
    my $method = 'validate_disallowed_chars';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error(
        disallowed_chars => 'contains characters that are disallowed',
        [ 'q' ],
    );

    my $first_name = 'Dq';

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($first_name) ],
            [ $error                     ],
            "$first_name constains invalid characters for " . $obj->get_label,
        );
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method( {} )  ], [], 'handles non-string';
}

VALIDATE_FORMAT: {
    my $method = 'validate_format';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error(
        format => 'does not match the expected format',
    );

    my $first_name = 'DAN';

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($first_name) ],
            [ $error                     ],
            "$first_name is an invalid format for " . $obj->get_label,
        );
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method( {} )  ], [], 'handles non-string';
}

NO_ALLOWED_DISALLOWED_CHARS: {
    my %attributes = (
        %attributes,
        allowed_chars    => [],
        disallowed_chars => [],
    );

    isa_ok my $obj = $class->new( \%attributes ), $class;

    my $first_name = 'Dan';

    my @results = $obj->validate($first_name);
    is_deeply \@results, [], "$first_name is a valid " . $obj->get_label;
}

NO_MIN_MAX_LENGTH: {
    my %attributes = (
        %attributes,
        min_length => undef,
        max_length => undef,
    );

    isa_ok my $obj = $class->new( \%attributes ), $class;

    foreach my $first_name ( 'A', 'A' . 'a' x 40 ) {
        my @results = $obj->validate($first_name);
        is_deeply \@results, [], "$first_name is a valid " . $obj->get_label;
    }
}
