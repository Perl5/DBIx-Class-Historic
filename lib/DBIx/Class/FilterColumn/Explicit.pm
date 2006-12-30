package DBIx::Class::FilterColumn::Explicit;

use strict;
use warnings;
use base qw/DBIx::Class/;

__PACKAGE__->load_components(qw/FilterColumn/);

sub register_column {
  my ($self, $column, $info, @rest) = @_;
  $self->next::method($column, $info, @rest);
  return unless defined($info->{filter});
  $self->filter_column( $column => $info->{filter} );
}


1;
