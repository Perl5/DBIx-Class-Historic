#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 28;
use Test::NoWarnings;
use base qw(DBIx::Class::Field::Type::object);

BEGIN {

    package Vehicle;

    use overload '""' => sub { ref shift };

    sub new { bless {}, shift }
    sub steer { }
    sub brake { }
    sub gas   { }

    package Jeep;

    use base qw(Vehicle);

    sub four_wheel_drive { }
    sub wave             { }    # Its a Jeep thing

    package Sidekick;

    use base qw(Vehicle);

    sub four_wheel_drive { }
    sub tip_over         { }

    package Pinto;

    use base qw(Vehicle);

    sub blow_up { }
}

my $class = __PACKAGE__;

my %attributes = (
    name    => 'off_road_vehicle',
    label   => 'Off Road Vehicle',
    roles   => [ qw( steer brake gas four_wheel_drive ) ],
    classes => [ qw( Vehicle Jeep                     ) ],
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

    my $jeep = Jeep->new;

    my @results = $obj->$method($jeep);

    is_deeply \@results, [], "$jeep is a good " . $obj->get_label;
}

VALIDATE_IS_OBJECT: {
    my $method = 'validate_is_object';

    can_ok $obj, $method;

    my $car = 'A car';

    my ($error) = $obj->$method( is_object => 'is not an object' );

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($car) ],
            [ $error              ],
            "$car is invalid, " . $obj->get_label . ' must be an object',
        );

        is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    }
}

VALIDATE_ROLES: {
    my $method = 'validate_roles';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error(
        roles => 'does not handle the necessary roles',
        [ qw( four_wheel_drive ) ],
    );

    my $pinto = Pinto->new;

    is_deeply(
        [ $obj->$method($pinto) ],
        [ $error                ],
        "$pinto does not support the necessary roles for "
            . $obj->get_label,
    );

    # returns error for the mismatch in classes too
    my ($classes_error) = $obj->validation_error(
        classes => 'does not inherit from the necessary classes',
        [ qw( Jeep ) ],
    );

    is_deeply(
        [ $obj->validate($pinto)  ],
        [ $error, $classes_error ],
        "$pinto does not support the necessary roles for "
            . $obj->get_label,
    );

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method('A')   ], [], 'handles non-object';
}

VALIDATE_CLASSES: {
    my $method = 'validate_classes';

    can_ok $obj, $method;

    my ($error) = $obj->validation_error(
        classes => 'does not inherit from the necessary classes',
        [ qw( Jeep ) ],
    );

    my $sidekick = Sidekick->new;

    foreach my $method ( 'validate', $method ) {
        is_deeply(
            [ $obj->$method($sidekick) ],
            [ $error                   ],
            "$sidekick does not inherit from the necessary classes for "
                . $obj->get_label,
        );
    }

    is_deeply [ $obj->$method(undef) ], [], 'handles undef';
    is_deeply [ $obj->$method('A')   ], [], 'handles non-object';
}
