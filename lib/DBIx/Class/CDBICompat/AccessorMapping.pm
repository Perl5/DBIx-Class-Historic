package DBIx::Class::CDBICompat::AccessorMapping;

use strict;
use warnings;

use NEXT;

sub mk_group_accessors {
  my ($class, $group, @cols) = @_;
  foreach my $col (@cols) {
    my $ro_meth = ($class->can('accessor_name')
                    ? $class->accessor_name($col)
                    : $col);
    my $wo_meth = ($class->can('mutator_name')
                    ? $class->mutator_name($col)
                    : $col);       

    my $field = $class->get_field($col);
    $field->set_accessor_name($ro_meth);
    $field->set_mutator_name($wo_meth);

    if ($ro_meth eq $wo_meth) {
      $class->NEXT::ACTUAL::mk_group_accessors($group => [ $ro_meth => $col ]);
    } else {
      $class->mk_group_ro_accessors($group => [ $ro_meth => $col ]);
      $class->mk_group_wo_accessors($group => [ $wo_meth => $col ]);
    }
  }
}

sub create {
  my ($class, $attrs, @rest) = @_;
  $class->throw( "create needs a hashref" ) unless ref $attrs eq 'HASH';
  $attrs = { %$attrs };
  my %att;
  foreach my $col (keys %{ $class->_columns }) {
    my $field = $class->get_field($col);

    my $acc = $field->get_accessor_name;
    $att{$col} = delete $attrs->{$acc} if exists $attrs->{$acc};

    my $mut = $field->get_mutator_name;
    $att{$col} = delete $attrs->{$mut} if exists $attrs->{$mut};
  }
  return $class->NEXT::ACTUAL::create({ %$attrs, %att }, @rest);
}

1;
