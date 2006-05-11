package DBIx::Class::Storage::DBI::mysql;

use strict;
use warnings;

use base qw/
  DBIx::Class::Storage::DBI::MultiColumnIn
  DBIx::Class::Storage::DBI
/;
use mro 'c3';

__PACKAGE__->sql_maker_class('DBIx::Class::SQLMaker::MySQL');
__PACKAGE__->sql_limit_dialect ('LimitXY');

sub with_deferred_fk_checks {
  my ($self, $sub) = @_;

  $self->_do_query('SET FOREIGN_KEY_CHECKS = 0');
  $sub->();
  $self->_do_query('SET FOREIGN_KEY_CHECKS = 1');
}

sub connect_call_set_strict_mode {
  my $self = shift;

  # the @@sql_mode puts back what was previously set on the session handle
  $self->_do_query(q|SET SQL_MODE = CONCAT('ANSI,TRADITIONAL,ONLY_FULL_GROUP_BY,', @@sql_mode)|);
  $self->_do_query(q|SET SQL_AUTO_IS_NULL = 0|);
}

sub _dbh_last_insert_id {
  my ($self, $dbh, $source, $col) = @_;
  $dbh->{mysql_insertid};
}

# we need to figure out what mysql version we're running
sub sql_maker {
  my $self = shift;

  unless ($self->_sql_maker) {
    my $maker = $self->next::method (@_);

    # mysql 3 does not understand a bare JOIN
    my $mysql_ver = $self->_get_dbh->get_info(18);
    $maker->{_default_jointype} = 'INNER' if $mysql_ver =~ /^3/;
  }

  return $self->_sql_maker;
}

sub sqlt_type {
  return 'MySQL';
}

sub deployment_statements {
  my $self = shift;
  my ($schema, $type, $version, $dir, $sqltargs, @rest) = @_;

  $sqltargs ||= {};

  if (
    ! exists $sqltargs->{producer_args}{mysql_version}
      and 
    my $dver = $self->_server_info->{normalized_dbms_version}
  ) {
    $sqltargs->{producer_args}{mysql_version} = $dver;
  }

  $self->next::method($schema, $type, $version, $dir, $sqltargs, @rest);
}

sub _svp_begin {
    my ($self, $name) = @_;

    $self->_get_dbh->do("SAVEPOINT $name");
}

sub _svp_release {
    my ($self, $name) = @_;

    $self->_get_dbh->do("RELEASE SAVEPOINT $name");
}

sub _svp_rollback {
    my ($self, $name) = @_;

    $self->_get_dbh->do("ROLLBACK TO SAVEPOINT $name")
}

sub is_replicating {
    my $status = shift->_get_dbh->selectrow_hashref('show slave status');
    return ($status->{Slave_IO_Running} eq 'Yes') && ($status->{Slave_SQL_Running} eq 'Yes');
}

sub lag_behind_master {
    return shift->_get_dbh->selectrow_hashref('show slave status')->{Seconds_Behind_Master};
}

# MySql can not do subquery update/deletes, only way is slow per-row operations.
# This assumes you have set proper transaction isolation and use innodb.
sub _subq_update_delete {
  return shift->_per_row_update_delete (@_);
}


sub columns_info_for {
  my ($self, $table) = @_;

  my $result;

  if ($self->dbh->can('column_info')) {
    my $old_raise_err = $self->dbh->{RaiseError};
    my $old_print_err = $self->dbh->{PrintError};
    $self->dbh->{RaiseError} = 1;
    $self->dbh->{PrintError} = 0;
    eval {
      my $sth = $self->dbh->column_info( undef, undef, $table, '%' );
      $sth->execute();
      while ( my $info = $sth->fetchrow_hashref() ){
        my %column_info;
        $column_info{data_type}     = $info->{TYPE_NAME};
        $column_info{size}          = $info->{COLUMN_SIZE};
        $column_info{is_nullable}   = $info->{NULLABLE} ? 1 : 0;
        $column_info{default_value} = $info->{COLUMN_DEF};

        my %info = $self->_extract_mysql_specs($info);
        $column_info{$_} = $info{$_} for keys %info;

        $result->{$info->{COLUMN_NAME}} = \%column_info;
      }
    };
    $self->dbh->{RaiseError} = $old_raise_err;
    $self->dbh->{PrintError} = $old_print_err;
    return {} if $@;
  }

  return $result;
}

sub _extract_mysql_specs {
  my ($self, $info) = @_;

  my $basetype   = lc($info->{TYPE_NAME});
  my $mysql_type = lc($info->{mysql_type_name});
  my %column_info;

  if ($basetype eq 'char') {
    if ($self->dbh->{mysql_serverinfo} < version->new('4.1')) {
      $column_info{length_in_bytes} = 1;
    }
    $column_info{ignore_trailing_spaces} = 1;
  }
  elsif ($basetype eq 'varchar') {
    if ($self->dbh->{mysql_serverinfo} <= version->new('4.1')) {
      $column_info{ignore_trailing_spaces} = 1;
    }
    if ($self->dbh->{mysql_serverinfo} < version->new('4.1')) {
      $column_info{length_in_bytes} = 1;
    }
  }
  elsif ($basetype =~ /text$/) {
    if ($basetype =~ /blob$/) {
      $column_info{length_in_bytes} = 1;
    }
    elsif ($self->dbh->{mysql_serverinfo} < version->new('4.1')) {
      $column_info{length_in_bytes} = 1;
    }
  }
  elsif ($basetype eq 'binary') {
    $column_info{ignore_trailing_spaces} = 1;
    $column_info{length_in_bytes}        = 1;
  }
  elsif ($basetype eq 'varbinary') {
    if ($self->dbh->{mysql_serverinfo} <= version->new('4.1')) {
      $column_info{ignore_trailing_spaces} = 1;
    }
    $column_info{length_in_bytes} = 1;
  }
  elsif ($basetype =~ /^(enum|set)/) {
    $column_info{data_set} = $info->{mysql_values};
  }
  elsif ($basetype =~ /int$/) {
    if ($mysql_type =~ /unsigned /) {
      my %max = (
        tinyint   => 2**8 - 1,
        smallint  => 2**16 - 1,
        mediumint => 2**24 - 1,
        int       => 2**32 - 1,
        bigint    => 2**64 - 1,
      );
      $column_info{is_unsigned} = 1;
      $column_info{range_min}   = 0;
      $column_info{range_max}   = $max{$basetype};
    }
    else { # not unsigned
      my %min = (
        tinyint   => - 2**7,
        smallint  => - 2**15,
        mediumint => - 2**23,
        int       => - 2**31,
        bigint    => - 2**63,
      );
      my %max = (
        tinyint   => 2**7 - 1,
        smallint  => 2**15 - 1,
        mediumint => 2**23 - 1,
        int       => 2**31 - 1,
        bigint    => 2**63 - 1,
      );
      $column_info{range_min} = $min{$basetype};
      $column_info{range_max} = $max{$basetype};
    }
  }
  elsif ($basetype =~ /^decimal/) {
    if ($self->dbh->{mysql_serverinfo} <= version->new('4.1')) {
      $column_info{decimal_high_positive} = 1;
    }
    if ($self->dbh->{mysql_serverinfo} < version->new('3.23')) {
      $column_info{decimal_literal_range} = 1;
    }
    $column_info{decimal_digits} = $info->{DECIMAL_DIGITS};
  }

  return %column_info;
}

1;

=head1 NAME

DBIx::Class::Storage::DBI::mysql - Storage::DBI class implementing MySQL specifics

=head1 SYNOPSIS

Storage::DBI autodetects the underlying MySQL database, and re-blesses the
C<$storage> object into this class.

  my $schema = MyDb::Schema->connect( $dsn, $user, $pass, { on_connect_call => 'set_strict_mode' } );

=head1 DESCRIPTION

This class implements MySQL specific bits of L<DBIx::Class::Storage::DBI>,
like AutoIncrement column support and savepoints. Also it augments the
SQL maker to support the MySQL-specific C<STRAIGHT_JOIN> join type, which
you can use by specifying C<< join_type => 'straight' >> in the
L<relationship attributes|DBIx::Class::Relationship::Base/join_type>


It also provides a one-stop on-connect macro C<set_strict_mode> which sets
session variables such that MySQL behaves more predictably as far as the
SQL standard is concerned.

=head1 STORAGE OPTIONS

=head2 set_strict_mode

Enables session-wide strict options upon connecting. Equivalent to:

  ->connect ( ... , {
    on_connect_do => [
      q|SET SQL_MODE = CONCAT('ANSI,TRADITIONAL,ONLY_FULL_GROUP_BY,', @@sql_mode)|,
      q|SET SQL_AUTO_IS_NULL = 0|,
    ]
  });

=head1 AUTHORS

See L<DBIx::Class/CONTRIBUTORS>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
