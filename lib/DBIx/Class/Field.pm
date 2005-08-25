package DBIx::Class::Field;

# TODO: add a validate_is_read_only method that checks
#       the value with Scalar::Util::readonly OR
#       checks to see if it's tied into a Readonly class

# TODO: add a routine that checks to see if the value can
#       be tainted or not.  Default the taint attribute
#       to allow tainting in all values.  is_taintable

use version; our $VERSION = qv('0.2.0');

use strict;
use warnings FATAL => 'all';
use Carp qw( croak );
use List::MoreUtils qw( any none );
use Class::Std;
{
    my %name_of              : ATTR( :init_arg<name>              :get<name>                                                      );
    my %accessor_name_of     : ATTR( :init_arg<accessor_name>     :get<accessor_name>     :set<accessor_name>                     );
    my %mutator_name_of      : ATTR( :init_arg<mutator_name>      :get<mutator_name>      :set<mutator_name>                      );
    my %label_of             : ATTR( :init_arg<label>             :get<label>             :set<label>                             );
    my %description_of       : ATTR( :init_arg<description>       :get<description>       :set<description>       :default<undef> );
    my %allowed_values_of    : ATTR( :init_arg<allowed_values>    :get<allowed_values>    :set<allowed_values>    :default<[]>    );
    my %disallowed_values_of : ATTR( :init_arg<disallowed_values> :get<disallowed_values> :set<disallowed_values> :default<[]>    );
    my %callbacks_of         : ATTR( :init_arg<callbacks>         :get<callbacks>         :set<callbacks>         :default<[]>    );
    my %is_read_only         : ATTR( :init_arg<is_read_only>      :get<is_read_only>      :set<is_read_only>      :default<0>     );
    my %is_required          : ATTR( :init_arg<is_required>       :get<is_required>       :set<is_required>       :default<0>     );
    my %default_of           : ATTR( :init_arg<default>           :get<default>           :set<default>           :default<undef> );

    sub BUILD : method {
        my ( $self, $ident, $arg_ref ) = @_;

        $accessor_name_of{$ident} = $arg_ref->{accessor_name}
            || $arg_ref->{name};
        
        $mutator_name_of{$ident}  = $arg_ref->{mutator_name}
            || $arg_ref->{name};

        if(!exists $arg_ref->{label}) {
            $label_of{$ident} = join(
                ' ',
                map { ucfirst(lc $_) }
                split '_',
                $arg_ref->{name},
            );
        }

        return;
    }

    sub validate : CUMULATIVE method {
        shift->_validate(
            shift,
            'required',
            qw(validate_callbacks allowed_values disallowed_values),
        );
    }

    sub validate_is_required : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # check if the value must be defined
        return
            if defined $value
            || !$self->get_is_required;

        return $self->validation_error( is_required => 'is required' );
    }

    sub validate_allowed_values : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # check if the defined value is allowed
        return if !defined $value;

        my $allowed_values = $self->get_allowed_values;

        return
            if !@$allowed_values
            || any { $value eq $_ } @$allowed_values;

        return $self->validation_error(
            allowed_values => 'is not an allowed value',
        );
    }

    sub validate_disallowed_values : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # check if the defined value is disallowed
        return if !defined $value;

        my $disallowed_values = $self->get_disallowed_values;

        return
            if !@$disallowed_values
            || none { $value eq $_ } @$disallowed_values;

        return $self->validation_error(
            disallowed_values => 'is a disallowed value',
        );
    }

    sub validate_callbacks : CUMULATIVE method {
        my ( $self, $value ) = @_;

        # check if the defined value passes the callbacks
        return if !defined $value;

        my $callbacks = $self->get_callbacks;
        return if !@$callbacks;

        return $self->validate_with( $value => @$callbacks );
    }

    sub validation_error : CUMULATIVE method {
        my ( $self, $rule, $desc, $data ) = @_;

        # return an error message with an identifier
        my $label = defined $self->get_label() ? $self->get_label()
                  :                              $self->get_name()
                  ;

        my %error = (
            rule    => $rule,
            message => "$label $desc",
        );

        if ( defined $data ) {
            $error{data} = $data;
        }

        return \%error;
    }

    sub validate_with : CUMULATIVE method {
        my ( $self, $value, @rules ) = @_;

        my @methods;

        # rules can be either a code-reference, a named-method in
        # the $self object, or a built-in validation method
        RULE:
        foreach my $rule (@rules) {
            my $code_ref;
            if ( ref $rule eq 'CODE' ) {
                push @methods, $rule;
            }
            elsif ( $code_ref = $self->can($rule) ) {
                push @methods, $code_ref;
            }
            elsif ( $code_ref = $self->can( 'get_' . $rule ) ) {
                next RULE if !defined $self->$code_ref();
                push @methods, $self->can( 'validate_' . $rule );
            }
            else {
                croak "Unknown rule type $rule";
            }
        }

        # execute all the rules
        return map { $_->( $self, $value ) } @methods;
    }

    sub type_of : method {
        my ( $self, $expected ) = @_;

        foreach my $type ( $self->types ) {
            return 1 if $type eq $expected;
        }

        return;
    }

    sub types : CUMULATIVE method { 'field' }

    sub _validate : RESTRICTED method {
        my ($self, $value, $type, @rules) = @_;

        # perform a basic check of the value
        my $base_check_ref = $self->can( 'validate_is_' . $type );

        if ( my ($error) = $self->$base_check_ref($value) ) {
            return $error;
        }

        # use each rule to validate the value
        return $self->validate_with( $value => @rules );
    }

}

1;
