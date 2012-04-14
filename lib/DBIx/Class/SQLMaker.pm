package DBIx::Class::SQLMaker;

use strict;
use warnings;

=head1 NAME

DBIx::Class::SQLMaker - An SQL::Abstract-based SQL maker class

=head1 DESCRIPTION

This module is a subclass of L<SQL::Abstract> and includes a number of
DBIC-specific workarounds, not yet suitable for inclusion into the
L<SQL::Abstract> core. It also provides all (and more than) the functionality
of L<SQL::Abstract::Limit>, see L<DBIx::Class::SQLMaker::LimitDialects> for
more info.

Currently the enhancements to L<SQL::Abstract> are:

=over

=item * Support for C<JOIN> statements (via extended C<table/from> support)

=item * Support of functions in C<SELECT> lists

=item * C<GROUP BY>/C<HAVING> support (via extensions to the order_by parameter)

=item * Support of C<...FOR UPDATE> type of select statement modifiers

=item * The L</-ident> operator

=item * The L</-value> operator

=back

=cut

use base qw/
  SQL::Abstract
  DBIx::Class::SQLMaker::LimitDialects
/;
use mro 'c3';

use Sub::Name 'subname';
use DBIx::Class::Carp;
use DBIx::Class::Exception;
use Data::Query::Constants qw(DQ_ALIAS DQ_GROUP DQ_WHERE DQ_JOIN);
use namespace::clean;
use Moo;

has limit_dialect => (is => 'rw', trigger => sub { shift->clear_renderer });

# for when I need a normalized l/r pair
sub _quote_chars {
  map
    { defined $_ ? $_ : '' }
    ( ref $_[0]->{quote_char} ? (@{$_[0]->{quote_char}}) : ( ($_[0]->{quote_char}) x 2 ) )
  ;
}

# FIXME when we bring in the storage weaklink, check its schema
# weaklink and channel through $schema->throw_exception
sub throw_exception { DBIx::Class::Exception->throw($_[1]) }

BEGIN {
  # reinstall the belch()/puke() functions of SQL::Abstract with custom versions
  # that use DBIx::Class::Carp/DBIx::Class::Exception instead of plain Carp
  no warnings qw/redefine/;

  *SQL::Abstract::belch = subname 'SQL::Abstract::belch' => sub (@) {
    my($func) = (caller(1))[3];
    carp "[$func] Warning: ", @_;
  };

  *SQL::Abstract::puke = subname 'SQL::Abstract::puke' => sub (@) {
    my($func) = (caller(1))[3];
    __PACKAGE__->throw_exception("[$func] Fatal: " . join ('',  @_));
  };

  # Current SQLA pollutes its namespace - clean for the time being
  namespace::clean->clean_subroutines(qw/SQL::Abstract carp croak confess/);
}

# the "oh noes offset/top without limit" constant
# limited to 31 bits for sanity (and consistency,
# since it may be handed to the like of sprintf %u)
#
# Also *some* builds of SQLite fail the test
#   some_column BETWEEN ? AND ?: 1, 4294967295
# with the proper integer bind attrs
#
# Implemented as a method, since ::Storage::DBI also
# refers to it (i.e. for the case of software_limit or
# as the value to abuse with MSSQL ordered subqueries)
sub __max_int () { 0x7FFFFFFF };

# poor man's de-qualifier
sub _quote {
  $_[0]->next::method( ( $_[0]{_dequalify_idents} and ! ref $_[1] )
    ? $_[1] =~ / ([^\.]+) $ /x
    : $_[1]
  );
}

sub _where_op_NEST {
  carp_unique ("-nest in search conditions is deprecated, you most probably wanted:\n"
      .q|{..., -and => [ \%cond0, \@cond1, \'cond2', \[ 'cond3', [ col => bind ] ], etc. ], ... }|
  );

  shift->next::method(@_);
}

# Handle limit-dialect selection
sub select {
  my ($self, $table, $fields, $where, $rs_attrs, $limit, $offset) = @_;

  if (defined $offset) {
    $self->throw_exception('A supplied offset must be a non-negative integer')
      if ( $offset =~ /\D/ or $offset < 0 );
  }
  $offset ||= 0;

  if (defined $limit) {
    $self->throw_exception('A supplied limit must be a positive integer')
      if ( $limit =~ /\D/ or $limit <= 0 );
  }
  elsif ($offset) {
    $limit = $self->__max_int;
  }


  my ($sql, @bind);
  if ($limit) {
    # this is legacy code-flow from SQLA::Limit, it is not set in stone

    ($sql, @bind) = $self->next::method ($table, $fields, $where);

    my $limiter =
      $self->can ('emulate_limit')  # also backcompat hook from SQLA::Limit
        ||
      do {
        my $dialect = $self->limit_dialect
          or $self->throw_exception( "Unable to generate SQL-limit - no limit dialect specified on $self, and no emulate_limit method found" );
        $self->can ("_$dialect")
          or $self->throw_exception(__PACKAGE__ . " does not implement the requested dialect '$dialect'");
      }
    ;

    $sql = $self->$limiter (
      $sql,
      { %{$rs_attrs||{}}, _selector_sql => $fields },
      $limit,
      $offset
    );
  }
  else {
    ($sql, @bind) = $self->next::method ($table, $fields, $where, $rs_attrs->{order_by}, $rs_attrs);
  }

  push @{$self->{where_bind}}, @bind;

# this *must* be called, otherwise extra binds will remain in the sql-maker
  my @all_bind = $self->_assemble_binds;

  $sql .= $self->_lock_select ($rs_attrs->{for})
    if $rs_attrs->{for};

  return wantarray ? ($sql, @all_bind) : $sql;
}

sub _assemble_binds {
  my $self = shift;
  return map { @{ (delete $self->{"${_}_bind"}) || [] } } (qw/pre_select select from where group having order limit/);
}

my $for_syntax = {
  update => 'FOR UPDATE',
  shared => 'FOR SHARE',
};
sub _lock_select {
  my ($self, $type) = @_;
  my $sql = $for_syntax->{$type} || $self->throw_exception( "Unknown SELECT .. FOR type '$type' requested" );
  return " $sql";
}

# Handle default inserts
sub insert {
# optimized due to hotttnesss
#  my ($self, $table, $data, $options) = @_;

  # SQLA will emit INSERT INTO $table ( ) VALUES ( )
  # which is sadly understood only by MySQL. Change default behavior here,
  # until SQLA2 comes with proper dialect support
  if (! $_[2] or (ref $_[2] eq 'HASH' and !keys %{$_[2]} ) ) {
    my @bind;
    my $sql = sprintf(
      'INSERT INTO %s DEFAULT VALUES', $_[0]->_quote($_[1])
    );

    if ( ($_[3]||{})->{returning} ) {
      my $s;
      ($s, @bind) = $_[0]->_insert_returning ($_[3]);
      $sql .= $s;
    }

    return ($sql, @bind);
  }

  next::method(@_);
}

around _select_field_to_dq => sub {
  my ($orig, $self) = (shift, shift);
  my ($field) = @_;
  my $ref = ref $field;
  if ($ref eq 'HASH') {
    my %hash = %$field;  # shallow copy

    my $as = delete $hash{-as};   # if supplied

    my ($func, $args, @toomany) = %hash;

    # there should be only one pair
    if (@toomany) {
      $self->throw_exception( "Malformed select argument - too many keys in hash: " . join (',', keys %$field ) );
    }

    if (lc ($func) eq 'distinct' && ref $args eq 'ARRAY' && @$args > 1) {
      $self->throw_exception (
        'The select => { distinct => ... } syntax is not supported for multiple columns.'
       .' Instead please use { group_by => [ qw/' . (join ' ', @$args) . '/ ] }'
       .' or { select => [ qw/' . (join ' ', @$args) . '/ ], distinct => 1 }'
      );
    }

    my $field_dq = $self->_op_to_dq(
      apply => $self->_ident_to_dq(uc($func)),
      $self->_select_field_list_to_dq($args),
    );

    return $field_dq unless $as;

    return +{
      type => DQ_ALIAS,
      alias => $field_dq,
      as => $as
    };
  } else {
    return $self->$orig(@_);
  }
};

around _source_to_dq => sub {
  my ($orig, $self) = (shift, shift);
  my $attrs = $_[4]; # table, fields, where, order, attrs
  my $start_dq = $self->$orig(@_);
  return $start_dq unless $attrs->{group_by};
  my $grouped_dq = $self->_group_by_to_dq($attrs->{group_by}, $start_dq);
  return $grouped_dq unless $attrs->{having};
  +{
    type => DQ_WHERE,
    from => $grouped_dq,
    where => $self->_where_to_dq($attrs->{having})
  };
};

sub _group_by_to_dq {
  my ($self, $group, $from) = @_;
  +{
    type => DQ_GROUP,
    by => [ $self->_select_field_list_to_dq($group) ],
    from => $from,
  };
}

around _table_to_dq => sub {
  my ($orig, $self) = (shift, shift);
  my ($spec) = @_;
  if (my $ref = ref $spec ) {
    if ($ref eq 'ARRAY') {
      return $self->_join_to_dq(@$spec);
    }
    elsif ($ref eq 'HASH') {
      my ($as, $table, $toomuch) = ( map
        { $_ => $spec->{$_} }
        ( grep { $_ !~ /^\-/ } keys %$spec )
      );
      $self->throw_exception( "Only one table/as pair expected in from-spec but an exra '$toomuch' key present" )
        if defined $toomuch;

      return +{
        type => DQ_ALIAS,
        alias => $self->_table_to_dq($table),
        as => $as,
      };
    }
  }
  return $self->$orig(@_);
};

sub _join_to_dq {
  my ($self, $from, @joins) = @_;

  my $cur_dq = $self->_table_to_dq($from);

  foreach my $join (@joins) {
    my ($to, $on) = @$join;

    # check whether a join type exists
    my $to_jt = ref($to) eq 'ARRAY' ? $to->[0] : $to;
    my $join_type;
    if (ref($to_jt) eq 'HASH' and defined($to_jt->{-join_type})) {
      $join_type = $to_jt->{-join_type};
      $join_type =~ s/^\s+ | \s+$//xg;
    }

    $join_type ||= $self->{_default_jointype};

    $cur_dq = +{
      type => DQ_JOIN,
      ($join_type ? (outer => $join_type) : ()),
      join => [ $cur_dq, $self->_table_to_dq($to) ],
      ($on
        ? (on => $self->_expr_to_dq($self->_expand_join_condition($on)))
        : ()),
    };
  }

  return $cur_dq;
}

sub _expand_join_condition {
  my ($self, $cond) = @_;

  # Backcompat for the old days when a plain hashref
  # { 't1.col1' => 't2.col2' } meant ON t1.col1 = t2.col2
  # Once things settle we should start warning here so that
  # folks unroll their hacks
  if (
    ref $cond eq 'HASH'
      and
    keys %$cond == 1
      and
    (keys %$cond)[0] =~ /\./
      and
    ! ref ( (values %$cond)[0] )
  ) {
    return +{ keys %$cond => { -ident => values %$cond } }
  }
  elsif ( ref $cond eq 'ARRAY' ) {
    return [ map $self->_expand_join_condition($_), @$cond ];
  }

  return $cond;
}

1;

=head1 OPERATORS

=head2 -ident

Used to explicitly specify an SQL identifier. Takes a plain string as value
which is then invariably treated as a column name (and is being properly
quoted if quoting has been requested). Most useful for comparison of two
columns:

    my %where = (
        priority => { '<', 2 },
        requestor => { -ident => 'submitter' }
    );

which results in:

    $stmt = 'WHERE "priority" < ? AND "requestor" = "submitter"';
    @bind = ('2');

=head2 -value

The -value operator signals that the argument to the right is a raw bind value.
It will be passed straight to DBI, without invoking any of the SQL::Abstract
condition-parsing logic. This allows you to, for example, pass an array as a
column value for databases that support array datatypes, e.g.:

    my %where = (
        array => { -value => [1, 2, 3] }
    );

which results in:

    $stmt = 'WHERE array = ?';
    @bind = ([1, 2, 3]);

=head1 AUTHORS

See L<DBIx::Class/CONTRIBUTORS>.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut
