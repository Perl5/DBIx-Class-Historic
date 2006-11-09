package DBIx::Class::Storage::DBI::mysql;

use strict;
use warnings;

use base qw/DBIx::Class::Storage::DBI/;

# __PACKAGE__->load_components(qw/PK::Auto/);

sub _dbh_last_insert_id {
  my ($self, $dbh, $source, $col) = @_;
  $dbh->{mysql_insertid};
}

sub sqlt_type {
  return 'MySQL';
}


my @table_privileges = (qw/
    ALTER
    CREATE
    DELETE
    FILE
    INDEX
    INSERT
    SELECT
    UPDATE
    USAGE/,
    'CREATE TEMPORARY TABLE',
    'LOCK TABLES',
    'CREATE VIEW');

my @dba_privileges = (
    'CREATE USER',
    'DROP',
    'EVENT',
    'PROCESS',
    'RELOAD',
    'REPLICATION CLIENT',
    'REPLICATION SLAVE',
    'SHUTDOWN',
    'SUPER',
    'GRANT OPTION',
    'ALL',
    'ALL PRIVILEGES');

my @stored_func_privileges = (
    'ALTER ROUTINE',
    'CREATE ROUTINE',
    'EXECUTE',
    'TRIGGER');

sub known_privileges {
    return { map { $_ => 1 } @table_privileges, @dba_privileges, @stored_func_privileges };
}

sub set_user_password {
    my ($self, $user, $password) = @_;

    return "SET PASSWORD FOR $user = PASSWORD('$password')";
}

sub current_schema {
    my ($self) = @_;
    return $self->dbh->selectrow_arrayref("SELECT DATABASE()")->[0];
}

sub post_grant {
    my ($self) = @_;
    $self->dbh->do('FLUSH PRIVILEGES');
}

1;

=head1 NAME

DBIx::Class::Storage::DBI::mysql - Automatic primary key class for MySQL

=head1 SYNOPSIS

  # In your table classes
  __PACKAGE__->load_components(qw/PK::Auto Core/);
  __PACKAGE__->set_primary_key('id');

=head1 DESCRIPTION

This class implements autoincrements for MySQL.

=head1 AUTHORS

Matt S. Trout <mst@shadowcatsystems.co.uk>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
