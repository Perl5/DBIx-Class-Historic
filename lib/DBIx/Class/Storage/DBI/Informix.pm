package DBIx::Class::Storage::DBI::Informix;
use strict;
use warnings;

use base qw/DBIx::Class::Storage::DBI/;
use mro 'c3';

use Scope::Guard ();
use Context::Preserve 'preserve_context';
use namespace::clean;

__PACKAGE__->sql_limit_dialect ('SkipFirst');
__PACKAGE__->sql_quote_char ('"');

__PACKAGE__->datetime_parse_via({
  datetime => '%Y-%m-%d %H:%M:%S.%5N',
  date     => '%m/%d/%Y',
});

__PACKAGE__->mk_group_accessors('simple' => '__last_insert_id');

=head1 NAME

DBIx::Class::Storage::DBI::Informix - Base Storage Class for Informix Support

=head1 DESCRIPTION

This class implements storage-specific support for the Informix RDBMS

=head1 METHODS

=cut

sub _execute {
  my $self = shift;
  my ($op) = @_;
  my ($rv, $sth, @rest) = $self->next::method(@_);

  $self->__last_insert_id($sth->{ix_sqlerrd}[1])
    if $self->_perform_autoinc_retrieval;

  return (wantarray ? ($rv, $sth, @rest) : $rv);
}

sub last_insert_id {
  shift->__last_insert_id;
}

sub _exec_svp_begin {
    my ($self, $name) = @_;

    $self->_dbh->do("SAVEPOINT $name");
}

# can't release savepoints
sub _exec_svp_release { 1 }

sub _exec_svp_rollback {
    my ($self, $name) = @_;

    $self->_dbh->do("ROLLBACK TO SAVEPOINT $name")
}

sub with_deferred_fk_checks {
  my ($self, $sub) = @_;

  my $txn_scope_guard = $self->txn_scope_guard;

  $self->_do_query('SET CONSTRAINTS ALL DEFERRED');

  my $sg = Scope::Guard->new(sub {
    $self->_do_query('SET CONSTRAINTS ALL IMMEDIATE');
  });

  return preserve_context { $sub->() } after => sub { $txn_scope_guard->commit };
}

=head2 connect_call_datetime_setup

Used as:

  on_connect_call => 'datetime_setup'

In L<connect_info|DBIx::Class::Storage::DBI/connect_info> to set the C<DATE> and
C<DATETIME> formats.

Sets the following environment variables:

    GL_DATE="%m/%d/%Y"
    GL_DATETIME="%Y-%m-%d %H:%M:%S%F5"

The C<DBDATE> and C<DBCENTURY> environment variables are cleared.

B<NOTE:> setting the C<GL_DATE> environment variable seems to have no effect
after the process has started, so the default format is used. The C<GL_DATETIME>
setting does take effect however.

The C<DATETIME> data type supports up to 5 digits after the decimal point for
second precision, depending on how you have declared your column. The full
possible precision is used.

The column declaration for a C<DATETIME> with maximum precision is:

  column_name DATETIME YEAR TO FRACTION(5)

The C<DATE> data type stores the date portion only, and it B<MUST> be declared
with:

  data_type => 'date'

in your Result class.

You will need the L<DateTime::Format::Strptime> module for inflation to work.

=cut

sub connect_call_datetime_setup {
  my $self = shift;

  delete @ENV{qw/DBDATE DBCENTURY/};

  $ENV{GL_DATE}     = "%m/%d/%Y";
  $ENV{GL_DATETIME} = "%Y-%m-%d %H:%M:%S%F5";
}

1;

=head1 AUTHOR

See L<DBIx::Class/AUTHOR> and L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
