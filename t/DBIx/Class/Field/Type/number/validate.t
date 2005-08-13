#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 53;
use Test::NoWarnings;
use base qw(DBIx::Class::Field::Type::number);

my $class = __PACKAGE__;

my %attributes = (
    name          => 'unit_price',
    label         => 'Unit Price',
    min_range     => 0,
    max_range     => 1000,
    min_precision => 2,
    max_precision => 2,
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

    foreach my $unit_price qw(0.00 500.00 1000.00) {
        my @results = $obj->$method($unit_price);
        is_deeply \@results, [], "$unit_price is a valid " . $obj->get_label;
    }
}

VALIDATE_IS_NUMBER: {
    my $method = 'validate_is_number';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error( is_number => 'is not a number' );

    my $not_a_number = 'some text';

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($not_a_number) ],
            [ $error                       ],
            "$not_a_number is invalid, "
                . $obj->get_label
                . ' must be a number',
        );

        is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    }
}

VALIDATE_MIN_RANGE: {
    my $method = 'validate_min_range';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error( min_range => 'is too small' );

    my $unit_price = -0.01;

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($unit_price) ],
            [ $error                     ],
            "$unit_price is too small of a value for " . $obj->get_label,
        );
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method('A')   ], [], 'handles non-number';
}

VALIDATE_MAX_RANGE: {
    my $method = 'validate_max_range';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error( max_range => 'is too large' );

    my $unit_price = 1000.01;

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($unit_price) ],
            [ $error                     ],
            "$unit_price is too large of a value for " . $obj->get_label,
        );
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method('A')   ], [], 'handles non-number';
}

VALIDATE_MIN_PRECISION: {
    my $method = 'validate_min_precision';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error(
        min_precision => 'has too few digits after the decimal point',
    );

    foreach my $unit_price (0.1, 1) {
        foreach my $method ( 'validate', $method ) {
            is_deeply(
                [ $obj->$method($unit_price) ],
                [ $error                     ],
                "$unit_price has too few precision places for "
                    . $obj->get_label,
            );
        }
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method('A')   ], [], 'handles non-number';
}

VALIDATE_MAX_PRECISION: {
    my $method = 'validate_max_precision';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error(
        max_precision => 'has too many digits after the decimal point',
    );

    my $unit_price = 0.001;

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($unit_price) ],
            [ $error                     ],
            "$unit_price has too many precision places for "
                . $obj->get_label,
        );
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method('A')   ], [], 'handles non-number';
}

NO_MIN_MAX_RANGE: {
    my %attributes = (
        %attributes,
        min_range => undef,
        max_range => undef,
    );

    isa_ok my $obj = $class->new( \%attributes ), $class;

    foreach my $unit_price ( -0.01, 1000.01 ) {
        my @results = $obj->validate($unit_price);
        is_deeply \@results, [], "$unit_price is a valid " . $obj->get_label;
    }
}

NO_MIN_MAX_RANGE: {
    my %attributes = (
        %attributes,
        min_precision => undef,
        max_precision => undef,
    );

    isa_ok my $obj = $class->new( \%attributes ), $class;

    foreach my $unit_price ( 0.1, 1, 0.001 ) {
        my @results = $obj->validate($unit_price);
        is_deeply \@results, [], "$unit_price is a valid " . $obj->get_label;
    }
}
