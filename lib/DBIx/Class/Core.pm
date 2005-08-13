package DBIx::Class::Core;

use strict;
use warnings;
no warnings 'qw';

use base qw/DBIx::Class/;

BEGIN {
  __PACKAGE__->load_components(qw/
    InflateColumn
    Relationship
    PK
    Row
    Validation
    Table
    Exception
    AccessorGroup
  /);

  __PACKAGE__->load_types(qw/
    column
    number
    object
    string
  /);
}

1;

=head1 NAME 

DBIx::Class::Core - Core set of DBIx::Class modules.

=head1 DESCRIPTION

This class just inherits from the various modules that makes 
up the DBIx::Class core features.


=head1 AUTHORS

Matt S. Trout <mst@shadowcatsystems.co.uk>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

