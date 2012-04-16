package DBIx::Class::SQLMaker::Converter;

use Data::Query::Constants qw(DQ_ALIAS DQ_GROUP DQ_WHERE DQ_JOIN DQ_SLICE);
use Moo;

extends 'SQL::Abstract::Converter';

around _select_to_dq => sub {
  my ($orig, $self) = (shift, shift);
  my $attrs = $_[4];
  my $orig_dq = $self->$orig(@_);
  return $orig_dq unless $attrs->{limit};
  +{
    type => DQ_SLICE,
    from => $orig_dq,
    limit => $self->_value_to_dq($attrs->{limit}),
    ($attrs->{offset}
      ? (offset => $self->_value_to_dq($attrs->{offset}))
      : ()
    ),
  };
};

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
      @{$self->_select_field_list_to_dq($args)},
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
    by => $self->_select_field_list_to_dq($group),
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
