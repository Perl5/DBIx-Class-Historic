package DBIx::Class::Field::Type::string;

use version; our $VERSION = qv('0.2.0');

use strict;
use warnings FATAL => 'all';
use base qw(DBIx::Class::Field);
use Scalar::Util qw( refaddr );
use Class::Std;
{
    my %min_length_of       : ATTR( :init_arg<min_length>       :get<min_length>       :set<min_length>       :default<-100**100**100> );
    my %max_length_of       : ATTR( :init_arg<max_length>       :get<max_length>       :set<max_length>       :default< 100**100**100> );
    my %allowed_chars_of    : ATTR( :init_arg<allowed_chars>    :get<allowed_chars>    :set<allowed_chars>    :default<[]>             );
    my %disallowed_chars_of : ATTR( :init_arg<disallowed_chars> :get<disallowed_chars> :set<disallowed_chars> :default<[]>             );
    my %format_of           : ATTR( :init_arg<format>           :get<format>           :set<format>           :default<qr//>           );

    sub validate : CUMULATIVE method {
        shift->_validate(
            shift,
            string => qw(
                min_length    max_length
                allowed_chars disallowed_chars
                format
            ),
        );
    }

    sub validate_is_string : method {
        my ( $self, $value ) = @_;

        # validate that the value is a string
        return
            if !defined $value
            || !refaddr $value;

        return $self->validation_error( is_string => 'is not a string' );
    }

    sub validate_min_length : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the minimum length of a defined string
        return
            if !defined $value
            || $self->validate_is_string($value)
            || length $value >= $self->get_min_length;

        return $self->validation_error( min_length => 'is too short' );
    }

    sub validate_max_length : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the maximum length of a defined string
        return
            if !defined $value
            || $self->validate_is_string($value)
            || length $value <= $self->get_max_length;

        return $self->validation_error( max_length => 'is too long' );
    }

    sub validate_allowed_chars : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the allowed characters of a defined string
        return
            if !defined $value
            || $self->validate_is_string($value);

        my $allowed_chars = $self->get_allowed_chars;
        return if !@$allowed_chars;

        # match any character that is not allowed
        my $match = join '', map { quotemeta $_ } @$allowed_chars;
        return if !(my @bad_chars = $value =~ m/([^$match])/g);

        return $self->validation_error(
            allowed_chars => 'contains characters that are not allowed',
            \@bad_chars,
        );
    }

    sub validate_disallowed_chars : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the disallowed characters of a defined string
        return
            if !defined $value
            || $self->validate_is_string($value);

        my $disallowed_chars = $self->get_disallowed_chars;
        return if !@$disallowed_chars;

        # match any character that is explicitly disallowed
        my $match = join '', map { quotemeta $_ } @$disallowed_chars;
        return if !(my @bad_chars = $value =~ m/([$match])/g);

        return $self->validation_error(
            disallowed_chars => 'contains characters that are disallowed',
            \@bad_chars,
        );
    }

    sub validate_format : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # validate the format of a defined string
        return
            if !defined $value
            || $self->validate_is_string($value)
            || $value =~ $self->get_format;

        return $self->validation_error(
            format => 'does not match the expected format',
        );
    }

    sub types : CUMULATIVE method { 'string' }

}

1;
