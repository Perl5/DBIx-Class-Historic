#!perl -T

package My::Test;

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 8;
use Test::NoWarnings;
use base qw(DBIx::Class::Field::Type::auto_increment);

my $class = __PACKAGE__;

my $obj;

NEW: {
    my $method = 'new';

    can_ok $class, $method;

    my %attributes = (
        name  => 'id',
        table => 'customer',
    );

    isa_ok $obj = $class->$method( \%attributes ), $class;
}

TYPE_OF: {
    my $method = 'type_of';

    can_ok $obj, $method;

    foreach my $type qw(auto_increment number column field) {
        my ($is_type) = $obj->$method($type);
        ok $is_type, "object is a type of $type";
    }
}
