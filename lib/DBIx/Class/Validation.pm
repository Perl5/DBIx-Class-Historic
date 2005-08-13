package DBIx::Class::Validation;

use strict;
use warnings FATAL => 'all';
use Carp qw( croak );
use DBIx::Class::Field::Singleton;
use Class::Std;
{

    sub load_types : RESTRICTED method {
        my ( $class, @types ) = @_;
        no strict 'refs';

        foreach my $type ( @types ) {
            my $isa = __PACKAGE__ . '::Type::' . $type;
            eval "require $isa";
            croak $@ if $@;
            push @{"${class}::ISA"}, $isa;
        }

        return;
    }

    sub get_field : RESTRICTED method {
        my ( $class, $field_name ) = @_;

        croak 'must supply a field name'
            if !defined $field_name;

        my $field_class = $class . '::Field::' . $field_name;

        # if possible, load the field class
        eval "require $field_class";

        # get the instance if it is defined
        my $field = eval { $field_class->get_instance };
        return $field if defined $field;

        # create the field class
        no strict 'refs';
        push @{"${field_class}::ISA"},
            grep { !UNIVERSAL::isa( $field_class, $_ ) }
            qw( DBIx::Class::Field::Singleton DBIx::Class::Field );

        # set a new field instance
        $field_class->set_instance( { name => $field_name } );
        return $field_class->get_instance;
    }

    sub set_field_label : RESTRICTED method {
        return shift->get_field(shift)->set_label(shift);
    }

    sub set_field_description : RESTRICTED method {
        return shift->get_field(shift)->set_description(shift);
    }

    sub set_field_default : RESTRICTED method {
        return shift->get_field(shift)->set_default(shift);
    }

    sub set_field_read_only : RESTRICTED method {
        return shift->get_field(shift)->set_is_read_only(1);
    }

    sub set_field : RESTRICTED method {
        my ( $class, $field_name, $attr ) = @_;

        while ( my ( $attr, $value ) = each %{$attr} ) {
            my $mutator = "set_field_$attr";
            $class->$mutator( $field_name => $value );
        }

        return;
    }

    sub validates_presence_of : RESTRICTED method {
        my ( $class, $field_name, $opt ) = @_;

        $class->get_field($field_name)->set_is_required(1);

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub validates_allowed_values_of : RESTRICTED method {
        my ( $class, $field_name, $allowed_values, $opt ) = @_;

        $class->get_field($field_name)
              ->set_allowed_values($allowed_values);

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub validates_disallowed_values_of : RESTRICTED method {
        my ( $class, $field_name, $disallowed_values, $opt ) = @_;

        $class->get_field($field_name)
              ->set_disallowed_values($disallowed_values);

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }

    sub validates_each_with : RESTRICTED method {
        my ( $class, $field_name, $callbacks, $opt ) = @_;

        $class->get_field($field_name)
              ->set_callbacks($callbacks);

        # TODO: set up trigger points based on the $opt passed in.  Want
        #       to be able to validate during different DBIx::Class
        #       operations.

        return;
    }
}

1;

__END__

# Inspiration:
# http://rails.rubyonrails.com/classes/ActiveRecord/Validations/ClassMethods.html

use base qw(DBIx::Class::Validation);

__PACKAGE__->load_classes(qw(string number object column));

# DBIx::Class::Validation
# ----------------------------

$table->set_field_label($field => 'Field');
$table->set_field_description($field => 'test')
$table->set_field_default($field => 'a default value');
$table->set_field_read_only($field);

# same as above -- shorthand
$table->set_field( $field => {
    label       => 'Field',
    description => 'test',
    default     => 'a default value',
    read_only   => 1,
});

$table->validates_presence_of($field);

$table->validates_allowed_values_of($field => \@allowed_values);
$table->validates_disallowed_values_of($field => \@disallowed_values);

$table->validates_each_with($field => \@callbacks);

# DBIx::Class::Validation::number
# -------------------------------

$table->validates_numericality_of($field);

$table->validates_range_of($field, { min => 1, max => 500 });

$table->validates_precision_of($field, { min => 1, max => 3 });

# DBIx::Class::Validation::string
# -------------------------------

$table->validates_length_of($field, { min => 1, max => 40 });

$table->validates_allowed_chars_of($field => [ qw( a b c d ) ]);
$table->validates_disallowed_chars_of($field => [ qw( a b c d ) ]);

$table->validates_format_of($field => qr/.*/);

# DBIx::Class::Validation::object
# -------------------------------

$table->validates_roles_of($field => \@roles);

$table->validates_classes_of($field => \@classes);

# DBIx::Class::Field::Validate::column
# ------------------------------------

$table->set_field_column($field => $column);

$table->set_field_inflate_deflate(
    $field,
    inflate => \%inflate,
    deflate => \%deflate,
);

# same as above -- shorthand
$table->set_field( $field => {
    column  => $column,
    inflate => \&inflate,
    deflate => \&deflate,
});
