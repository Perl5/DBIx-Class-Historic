package Jifty::DBI::Handle::Oracle;
use base qw/Jifty::DBI::Handle/;
use DBD::Oracle qw(:ora_types ORA_OCI);

use vars qw($VERSION $DBIHandle $DEBUG);

=head1 NAME

  Jifty::DBI::Handle::Oracle - An oracle specific Handle object

=head1 SYNOPSIS

=head1 DESCRIPTION

This module provides a subclass of L<Jifty::DBI::Handle> that
compensates for some of the idiosyncrasies of Oracle.

=head1 METHODS

=head2 connect PARAMHASH: Driver, Database, Host, User, Password

Takes a paramhash and connects to your DBI datasource. 

=cut

sub connect {
    my $self = shift;

    $self->dbh->{LongTruncOk} = 1;
    $self->dbh->{LongReadLen} = 8000;

    $self->simple_query(
        "ALTER SESSION set NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'");

    return ($DBIHandle);
}
=head2 blob_params column_NAME column_type

Returns a hash ref for the bind_param call to identify BLOB types used
by the current database for a particular column type.  The current
Oracle implementation only supports ORA_CLOB types (112).

=cut

sub blob_params {
    my $self   = shift;
    my $column = shift;

    # Don't assign to key 'value' as it is defined later.
    return (
        {   ora_column => $column,
            ora_type   => ORA_CLOB,
        }
    );
}

