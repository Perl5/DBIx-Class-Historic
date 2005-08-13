package DBIx::Class::Field::Singleton;

use version; our $VERSION = qv('0.2.0');

use strict;
use warnings FATAL => 'all';
use base qw(DBIx::Class::Field);
use Carp qw( croak );
use Scalar::Util qw( blessed );
{
    my %singleton_of;

    sub get_instance : method {
        my ($class) = @_;

        if ( !exists $singleton_of{$class} ) {
            croak "No singleton defined for $class";
        }

        return $singleton_of{$class};
    }

    sub set_instance : method {
        my ( $class, @args ) = @_;

        if ( blessed $class ) {
            croak "$class->instance is not an object method";
        }

        if ( $class eq __PACKAGE__ ) {
            croak "Can only use $class->set_instance from a subclass";
        }

        $singleton_of{$class} = $class->new(@args);

        return;
    }

    sub types : CUMULATIVE method { 'singleton' }

}

1;
