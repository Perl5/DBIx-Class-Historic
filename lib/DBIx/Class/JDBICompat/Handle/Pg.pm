package Jifty::DBI::Handle::Pg;
use strict;

use vars qw($VERSION @ISA $DBIHandle $DEBUG);
use base qw(Jifty::DBI::Handle);

use strict;

=head1 NAME

  Jifty::DBI::Handle::Pg - A Postgres specific Handle object

=head1 SYNOPSIS


=head1 DESCRIPTION

This module provides a subclass of L<Jifty::DBI::Handle> that
compensates for some of the idiosyncrasies of Postgres.

=head1 METHODS

=cut

=head2 connect

connect takes a hashref and passes it off to SUPER::connect; Forces
the timezone to GMT, returns a database handle.

=cut

sub connect {
    my $self = shift;

    $self->SUPER::connect(@_);
    $self->simple_query("SET TIME ZONE 'GMT'");
    $self->simple_query("SET DATESTYLE TO 'ISO'");
    $self->auto_commit(1);
    return ($DBIHandle);
}

1;
