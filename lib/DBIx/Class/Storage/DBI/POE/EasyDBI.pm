package DBIx::Class::Storage::DBI::POE::EasyDBI;

BEGIN {
  use Carp::Clan qw/^DBIx::Class/;
  use DBIx::Class;
  croak('The following modules are required for Replication ' . DBIx::Class::Optional::Dependencies->req_missing_for ('poe_easydbi') )
    unless DBIx::Class::Optional::Dependencies->req_ok_for ('poe_easydbi');
}

use strict;
use warnings;
use base qw/DBIx::Class::Storage::DBI/;
use mro 'c3';
use Carp::Clan qw/^DBIx::Class|^Try::Tiny/;
use Sub::Name;
use POE;
use POE::Component::EasyDBI;
use namespace::clean;

__PACKAGE__->mk_group_accessors(simple => qw/
  _normal_storage
/);

my @proxy_to_normal_storage = qw/
  sql_maker_class sql_limit_dialect sql_quote_char sql_name_sep
/;

=head1 NAME

DBIx::Class::Storage::DBI::POE::EasyDBI - Asynchronous Storage Driver Using
L<POE::Component::EasyDBI>

=head1 SYNOPSIS

  my $schema = Schema::Class->clone;
  $schema->storage_type('::DBI::POE::EasyDBI');
  $schema->connection(...);

=head1 DESCRIPTION

This is a L<DBIx::Class> storage driver for asynchronous applications using
L<POE::Component::EasyDBI>.

It can be used with L<POE> or any other asynchronous framework that has a L<POE>
adaptor or L<POE::Loop> for it. For L<AnyEvent>, for example, you can use
L<AnyEvent::Impl::POE>.

=head1 CAVEATS

=head2 reentrancy

The mechanism of supporting a synchronous API in an asynchronous system is
similar to that used by L<LWP::UserAgent::POE>. It is reentrant, however, the
most recent request must finish before ones already being waited on will
complete (the rest of the application, that does not depend on L<DBIx::Class>
still runs.) To keep your app responsive, I recommend avoiding long-running
queries.

=head2 transactions

Transactions are not currently supported at all.

=cut

# make a normal storage for proxying some methods
sub connect_info {
  my $self = shift;
  my ($info) = @_;

  my $storage = DBIx::Class::Storage::DBI->new;
  $storage->connect_info($info);
  $storage->_determine_driver;

  $self->_normal_storage($storage);

  return $self->next::method(@_);
}

for my $method (@proxy_to_normal_storage) {
  no strict 'refs';
  no warnings 'redefine';

  my $replaced = __PACKAGE__->can($method);

  *{$method} = subname $method => sub {
    my $self = shift;
    return $self->_normal_storage->$replaced(@_);
  };
}

1;

=head1 AUTHOR

See L<DBIx::Class/AUTHOR> and L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
# vim:sw=2 sts=2:
