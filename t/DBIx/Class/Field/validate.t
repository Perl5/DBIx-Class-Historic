#!perl -T

package My::Test;

# TODO: handle cases where the underlying attribute value is
#       undef.  With the introduction of the set_* methods this is
#       possible, although unlikely.

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 51;
use Test::Exception;
use Test::NoWarnings;
use base qw(DBIx::Class::Field);

my $class = __PACKAGE__;

my %attributes = (
    name              => 'customer_id',
    label             => 'Customer ID',
    description       => 'A unique identifier for a customer',
    allowed_values    => [ 2 .. 10 ],
    disallowed_values => [ 7       ],
    callbacks         => [ \&odd_numbers_only, 'odd_numbers_only' ],
    is_read_only      => 1,
    is_required       => 1,
    default           => 1,
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

    foreach my $id qw(3 5 9) {
        my @results = $obj->$method($id);
        is_deeply \@results, [], "$id is valid " . $obj->get_label;
    }
}

VALIDATION_ERROR_WITH_LABEL: {
    my $method = 'validation_error';

    can_ok $obj, $method;

    my %error = (
        rule    => 'rule_name',
        message => 'Customer ID rule message',
    );

    my ($error) = $obj->validation_error( rule_name => 'rule message' );

    is_deeply( $error, \%error, 'error message is correct' );
}

VALIDATION_ERROR_WITH_FIELD_NAME: {
    my $obj = $class->new( { name => 'customer_id' } );

    my %error = (
        rule    => 'rule_name',
        message => 'Customer Id rule message',
    );

    my ($error) = $obj->validation_error( rule_name => 'rule message' );

    is_deeply( $error, \%error, 'error message is correct' );
}

VALIDATE_IS_REQUIRED: {
    my $method = 'validate_is_required';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error( is_required => 'is required' );

    my $undef = undef;

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($undef) ],
            [ $error                ],
            "value cannot be undefined for " . $obj->get_label,
        );
    }
}

VALIDATE_ALLOWED_VALUES: {
    my $method = 'validate_allowed_values';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error(
        allowed_values => 'is not an allowed value',
    );

    foreach my $not_allowed qw(1 11) {
        foreach my $method ( 'validate', $method ) {
            is_deeply(
                [ $obj->$method($not_allowed) ],
                [ $error                      ],
                "$not_allowed is not an allowed value for " . $obj->get_label,
            );
        }
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
}

VALIDATE_DISALLOWED_VALUES: {
    my $method = 'validate_disallowed_values';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error(
        disallowed_values => 'is a disallowed value',
    );

    my $disallowed = 7;

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($disallowed) ],
            [ $error                     ],
            "$disallowed is a disallowed value for " . $obj->get_label,
        );
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
}

VALIDATE_CALLBACKS: {
    my $method = 'validate_callbacks';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error(
        odd_numbers_only => 'must be an odd number',
    );

    # testing both the subref and method-style of callbacks
    # at the same time therefore two identical errors are
    # expected.

    foreach my $even qw(2 4 6 8) {
        foreach my $method ( 'validate', $method ) {
            is_deeply(
                [ $obj->$method($even) ],
                [ $error, $error ],
                "$even is even, but " . $obj->get_label . ' must be odd',
            );
        }
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
}

BAD_CALLBACK_RULE: {
    my $obj = $class->new({
        name      => 'id',
        callbacks => [ qr// ],    # can only be a method or subref
    });

    dies_ok { $obj->validate(1)           } 'callback rule invalid';
    dies_ok { $obj->validate_callbacks(1) } 'callback rule invalid';
}

sub odd_numbers_only : method {
    my ( $obj, $value ) = @_;

    return if $value % 2;

    return $obj->validation_error(
        odd_numbers_only => 'must be an odd number',
    );
}
