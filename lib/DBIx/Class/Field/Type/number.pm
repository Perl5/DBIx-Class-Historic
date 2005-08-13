package DBIx::Class::Field::Type::number;

use version; our $VERSION = qv('0.2.0');

use strict;
use warnings FATAL => 'all';
use base qw(DBIx::Class::Field);
use Scalar::Util qw( looks_like_number );
use Class::Std;
{
    my %min_range_of     : ATTR( :init_arg<min_range>     :get<min_range>     :set<min_range>     :default<-100**100**100> );
    my %max_range_of     : ATTR( :init_arg<max_range>     :get<max_range>     :set<max_range>     :default< 100**100**100> );
    my %min_precision_of : ATTR( :init_arg<min_precision> :get<min_precision> :set<min_precision> :default<-100**100**100> );
    my %max_precision_of : ATTR( :init_arg<max_precision> :get<max_precision> :set<max_precision> :default< 100**100**100> );

    sub validate : CUMULATIVE method {
        shift->_validate(
            shift,
            number => qw( min_range max_range min_precision max_precision ),
        );
    }

    sub validate_is_number : method {
        my ( $self, $value ) = @_;

        # validate that the value is a number
        return
            if !defined $value
            || looks_like_number($value);

        return $self->validation_error( is_number => 'is not a number' );
    }

    sub validate_min_range : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the minimum range of a defined number
        return
            if !defined $value
            || $self->validate_is_number($value)
            || $value >= $self->get_min_range;

        return $self->validation_error( min_range => 'is too small' );
    }

    sub validate_max_range : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the maximum range of a defined number
        return
            if !defined $value
            || $self->validate_is_number($value)
            || $value <= $self->get_max_range;

        return $self->validation_error( max_range => 'is too large' );
    }

    sub validate_min_precision : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the minimum precision of a defined number
        return
            if !defined $value
            || $self->validate_is_number($value);

        my $precision_length = __PACKAGE__->_precision_length($value);
        return if $precision_length >= $self->get_min_precision;

        return $self->validation_error(
            min_precision => 'has too few digits after the decimal point',
        );
    }

    sub validate_max_precision : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the maximum precision of a defined number
        return
            if !defined $value
            || $self->validate_is_number($value);

        my $precision_length = __PACKAGE__->_precision_length($value);
        return if $precision_length <= $self->get_max_precision;

        return $self->validation_error(
            max_precision => 'has too many digits after the decimal point',
        );
    }

    sub _precision_length : PRIVATE method {
        my ( undef, $value ) = @_;

        # get the precision length of a number
        my $decimal_pos = index $value, '.';

        return 0 if $decimal_pos < 0;

        return length substr $value, $decimal_pos + 1;
    }

    sub types : CUMULATIVE method { 'number' }
}

1;
