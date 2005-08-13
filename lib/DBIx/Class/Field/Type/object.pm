package DBIx::Class::Field::Type::object;

use version; our $VERSION = qv('0.2.0');

use strict;
use warnings FATAL => 'all';
use base qw(DBIx::Class::Field);
use Scalar::Util qw( blessed );
use Class::Std;
{
    my %roles_of   : ATTR( :init_arg<roles>   :get<roles>   :set<roles>   :default<[]> );
    my %classes_of : ATTR( :init_arg<classes> :get<classes> :set<classes> :default<[]> );

    sub validate : CUMULATIVE method {
        shift->_validate(
            shift,
            object => qw( roles classes ),
        );
    }

    sub validate_is_object : method {
        my ( $self, $value ) = @_;

        # validate that the value is an object
        return
            if !defined $value
            || blessed $value;

        return $self->validation_error( is_object => 'is not an object' );
    }

    sub validate_roles : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the roles (supported methods) of a defined object
        return
            if !defined $value
            || $self->validate_is_object($value);

        my @need_roles = grep { !$value->can($_) } @{ $self->get_roles };
        return if !@need_roles;

        return $self->validation_error(
            roles => 'does not handle the necessary roles',
            \@need_roles,
        );
    }

    sub validate_classes : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the classes a defined object inherits from
        return
            if !defined $value
            || $self->validate_is_object($value);

        my @need_classes = grep { !$value->isa($_) } @{ $self->get_classes };
        return if !@need_classes;

        return $self->validation_error(
            classes => 'does not inherit from the necessary classes',
            \@need_classes,
        );
    }

    sub types : CUMULATIVE method { 'object' }

}

1;
