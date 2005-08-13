#!perl -T

use strict;
use warnings FATAL   => 'all';
use Test::More tests => 12;
use Test::Exception;
use Test::NoWarnings;

BEGIN {

    package My::Column;

    use base qw(
        DBIx::Class::Field::Singleton
        DBIx::Class::Field
    );

    package My::Column::Premature;

    use base qw(
        DBIx::Class::Field::Singleton
        DBIx::Class::Field
    );
}

my $class = 'My::Column';

SET_INSTANCE: {
    my $method = 'set_instance';

    can_ok $class, $method;

    is $class->$method({ name => 'id' }), undef;
}

my $obj;

GET_INSTANCE: {
    my $method = 'get_instance';

    can_ok $class, $method;
    isa_ok $obj = $class->$method, $class;

    is $class->$method, $class->$method, 'same object each time';
}

TYPE_OF: {
    my $method = 'type_of';

    can_ok $obj, $method;

    foreach my $type qw(singleton field) {
        my ($is_type) = $obj->$method($type);
        ok $is_type, "object is a type of $type";
    }
}

PREMATURE_GET_INSTANCE: {
    dies_ok { My::Column::Premature->get_instance } 'must set_instance first';
}

CLASS_METHOD_ONLY: {
    my $obj = bless {}, 'My::Column';
    dies_ok { $obj->set_instance } 'class method only';
}

SUBCLASSES_ONLY: {
    my $class = 'DBIx::Class::Field::Singleton';
    dies_ok { $class->set_instance } 'subclass use only';
}
