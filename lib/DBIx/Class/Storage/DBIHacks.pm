package   #hide from PAUSE
  DBIx::Class::Storage::DBIHacks;

#
# This module contains code that should never have seen the light of day,
# does not belong in the Storage, or is otherwise unfit for public
# display. The arrival of SQLA2 should immediately obsolete 90% of this
#

use strict;
use warnings;

use base 'DBIx::Class::Storage';
use mro 'c3';

use List::Util 'first';
use Scalar::Util 'blessed';
use Sub::Name 'subname';
use Data::Query::Constants qw(
  DQ_ALIAS DQ_JOIN DQ_IDENTIFIER DQ_ORDER DQ_LITERAL DQ_OPERATOR
);
use namespace::clean;

sub sqla_converter { shift->sql_maker->converter }

#
# This code will remove non-selecting/non-restricting joins from
# {from} specs, aiding the RDBMS query optimizer
#
sub _prune_unused_joins {
  my $self = shift;
  my ($from, $select, $where, $attrs) = @_;

  return $from unless $self->_use_join_optimizer;

  if (ref $from ne 'ARRAY' || ref $from->[0] ne 'HASH' || ref $from->[1] ne 'ARRAY') {
    return $from;   # only standard {from} specs are supported
  }

  my $aliastypes = $self->_resolve_aliastypes_from_select_args(@_);

  # a grouped set will not be affected by amount of rows. Thus any
  # {multiplying} joins can go
  delete $aliastypes->{multiplying}
    if $attrs->{group_by} or $attrs->{prune_multiplying};

  my @newfrom = $from->[0]; # FROM head is always present

  my %need_joins;
  for (values %$aliastypes) {
    # add all requested aliases
    $need_joins{$_} = 1 for keys %$_;

    # add all their parents (as per joinpath which is an AoH { table => alias })
    $need_joins{$_} = 1 for map { values %$_ } map { @$_ } values %$_;
  }

  for my $j (@{$from}[1..$#$from]) {
    push @newfrom, $j if (
      (! $j->[0]{-alias}) # legacy crap
        ||
      $need_joins{$j->[0]{-alias}}
    );
  }

  return \@newfrom;
}

#
# This is the code producing joined subqueries like:
# SELECT me.*, other.* FROM ( SELECT me.* FROM ... ) JOIN other ON ...
#
sub _adjust_select_args_for_complex_prefetch {
  my ($self, $from, $select, $where, $attrs) = @_;

  $self->throw_exception ('Nothing to prefetch... how did we get here?!')
    if not @{$attrs->{_prefetch_selector_range}};

  $self->throw_exception ('Complex prefetches are not supported on resultsets with a custom from attribute')
    if (ref $from ne 'ARRAY' || ref $from->[0] ne 'HASH' || ref $from->[1] ne 'ARRAY');


  # generate inner/outer attribute lists, remove stuff that doesn't apply
  my $outer_attrs = { %$attrs };
  delete $outer_attrs->{$_} for qw/where bind rows offset group_by having/;

  my $inner_attrs = { %$attrs, _is_internal_subuery => 1 };
  delete $inner_attrs->{$_} for qw/for collapse _prefetch_selector_range select as/;

  # if the user did not request it, there is no point using it inside
  delete $inner_attrs->{order_by} if delete $inner_attrs->{_order_is_artificial};

  # generate the inner/outer select lists
  # for inside we consider only stuff *not* brought in by the prefetch
  # on the outside we substitute any function for its alias
  my $outer_select = [ @$select ];
  my $inner_select = [];
  my %seen_inner;

  my ($p_start, $p_end) = @{$outer_attrs->{_prefetch_selector_range}};
  for my $i (0 .. $p_start - 1, $p_end + 1 .. $#$outer_select) {
    my $sel = $outer_select->[$i];

    if (ref $sel eq 'HASH' ) {
      $sel->{-as} ||= $attrs->{as}[$i];
      $outer_select->[$i] = join ('.', $attrs->{alias}, ($sel->{-as} || "inner_column_$i") );
    }

    $seen_inner{$sel} = 1;

    push @$inner_select, $sel;

    push @{$inner_attrs->{as}}, $attrs->{as}[$i];
  }

  # construct the inner $from and lock it in a subquery
  # we need to prune first, because this will determine if we need a group_by below
  # the fake group_by is so that the pruner throws away all non-selecting, non-restricting
  # multijoins (since we def. do not care about those inside the subquery)

  my $from_copy = $from;
  my $inner_subq = sub {

    # must use it here regardless of user requests
    local $self->{_use_join_optimizer} = 1;

    my $inner_from = $self->_prune_unused_joins ($from_copy, $inner_select, $where, {
      prune_multiplying => 1, %$inner_attrs,
    });

    my $inner_aliastypes =
      $self->_resolve_aliastypes_from_select_args( $inner_from, $inner_select, $where, $inner_attrs );

    # we need to simulate collapse in the subq if a multiplying join is pulled
    # by being a non-selecting restrictor
    if (
      ! $inner_attrs->{group_by}
        and
      first {
        $inner_aliastypes->{restricting}{$_}
          and
        ! $inner_aliastypes->{selecting}{$_}
      } ( keys %{$inner_aliastypes->{multiplying}||{}} )
    ) {
      my $unprocessed_order_chunks;
      ($inner_attrs->{group_by}, $unprocessed_order_chunks) = $self->_group_over_selection (
        $inner_from, $inner_select, $inner_attrs->{order_by}
      );

      $self->throw_exception (
        'A required group_by clause could not be constructed automatically due to a complex '
      . 'order_by criteria. Either order_by columns only (no functions) or construct a suitable '
      . 'group_by by hand'
      )  if @$unprocessed_order_chunks;
    }

    # we already optimized $inner_from above
    local $self->{_use_join_optimizer} = 0;

    # generate the subquery
    scalar $self->_select_args_to_query (
      $inner_from,
      $inner_select,
      $where,
      $inner_attrs,
    );
  };

  # Generate the outer from - this is relatively easy (really just replace
  # the join slot with the subquery), with a major caveat - we can not
  # join anything that is non-selecting (not part of the prefetch), but at
  # the same time is a multi-type relationship, as it will explode the result.
  #
  # There are two possibilities here
  # - either the join is non-restricting, in which case we simply throw it away
  # - it is part of the restrictions, in which case we need to collapse the outer
  #   result by tackling yet another group_by to the outside of the query

  $from = [ @$from ];

  # We'll need this in a moment
  my $head_from = $from->[0];

  # so first generate the outer_from, up to the substitution point
  my @outer_from;
  my $subq_container;
  while (my $j = shift @$from) {
    $j = [ $j ] unless ref $j eq 'ARRAY'; # promote the head-from to an AoH

    if ($j->[0]{-alias} eq $attrs->{alias}) { # time to swap

      push @outer_from, $subq_container = [
        {
          -alias => $attrs->{alias},
          -rsrc => $j->[0]{-rsrc},
          $attrs->{alias} => '__DUMMY__',
        },
        @{$j}[1 .. $#$j],
      ];
      last; # we'll take care of what's left in $from below
    }
    else {
      push @outer_from, $j;
    }
  }

  # scan the *remaining* from spec against different attributes, and see
  # which joins are needed in what role - we briefly re-add the old "head"
  # from node so that the join path is correct for the top join
  my $outer_aliastypes =
    $self->_resolve_aliastypes_from_select_args( [ $head_from, @$from ], $outer_select, $where, $outer_attrs );

  # unroll parents
  my ($outer_select_chain, $outer_restrict_chain) = map { +{
    map { $_ => 1 } map { values %$_} map { @$_ } values %{ $outer_aliastypes->{$_} || {} }
  } } qw/selecting restricting/;

  # see what's left - throw away if not selecting/restricting
  # also throw in a group_by if a non-selecting multiplier,
  # to guard against cross-join explosions
  my $need_outer_group_by;
  my @extra_outer_from;
  while (my $j = shift @$from) {
    my $alias = $j->[0]{-alias};

    if (
      $outer_select_chain->{$alias}
    ) {
      push @outer_from, $j;
      push @extra_outer_from, $j;
    }
    elsif ($outer_restrict_chain->{$alias}) {
      push @outer_from, $j;
      push @extra_outer_from, $j;
      $need_outer_group_by ||= $outer_aliastypes->{multiplying}{$alias} ? 1 : 0;
    }
  }

  $self->_scan_identifiers(
    sub {
      if (
        @{$_[0]->{elements}} > 1
        and $_[0]->{elements}[0] eq $attrs->{alias}
        and !$seen_inner{my $name = join('.', @{$_[0]->{elements}})}
      ) {
        push @$_, $name for $inner_select, $inner_attrs->{as};
      }
    },
    $self->sqla_converter->_table_to_dq([ $subq_container, @extra_outer_from ])
  );
  
  $subq_container->[0]{$attrs->{alias}} = $inner_subq->();

  # demote the outer_from head
  $outer_from[0] = $outer_from[0][0];

  if ($need_outer_group_by and ! $outer_attrs->{group_by}) {

    my $unprocessed_order_chunks;
    ($outer_attrs->{group_by}, $unprocessed_order_chunks) = $self->_group_over_selection (
      \@outer_from, $outer_select, $outer_attrs->{order_by}
    );

    $self->throw_exception (
      'A required group_by clause could not be constructed automatically due to a complex '
    . 'order_by criteria. Either order_by columns only (no functions) or construct a suitable '
    . 'group_by by hand'
    ) if @$unprocessed_order_chunks;

  }

  # This is totally horrific - the $where ends up in both the inner and outer query
  # Unfortunately not much can be done until SQLA2 introspection arrives, and even
  # then if where conditions apply to the *right* side of the prefetch, you may have
  # to both filter the inner select (e.g. to apply a limit) and then have to re-filter
  # the outer select to exclude joins you didin't want in the first place
  #
  # OTOH it can be seen as a plus: <ash> (notes that this query would make a DBA cry ;)
  return (\@outer_from, $outer_select, $where, $outer_attrs);
}

#
# I KNOW THIS SUCKS! GET SQLA2 OUT THE DOOR SO THIS CAN DIE!
#
# Due to a lack of SQLA2 we fall back to crude scans of all the
# select/where/order/group attributes, in order to determine what
# aliases are neded to fulfill the query. This information is used
# throughout the code to prune unnecessary JOINs from the queries
# in an attempt to reduce the execution time.
# Although the method is pretty horrific, the worst thing that can
# happen is for it to fail due to some scalar SQL, which in turn will
# result in a vocal exception.

sub _resolve_aliastypes_from_select_args {
  my ($self, $from, $select, $where, $attrs) = @_; # ICK

  $self->throw_exception ('Unable to analyze custom {from}')
    if ref $from ne 'ARRAY';

  # what we will return
  my $aliases_by_type;
  my $multiplying = $aliases_by_type->{multiplying} = {};
  my $restricting = $aliases_by_type->{restricting} = {};
  my $selecting = $aliases_by_type->{selecting} = {};
  # see what aliases are there to work with
  my $alias_list;

  my %col_map;

  my $schema = $self->schema;

  my $conv = $self->sqla_converter;

  my $from_dq = $conv->_table_to_dq($from);

  my (%join_dq, @alias_dq);

  while ($from_dq->{type} eq DQ_JOIN) {
    die "Don't understand this from"
      unless $from_dq->{right}{type} eq DQ_ALIAS;
    push @alias_dq, $from_dq->{right};
    $join_dq{$from_dq->{right}} = $from_dq;
    if (my $source_name = $from_dq->{right}{'dbix-class.source_name'}) {
      my @columns = $schema->source($source_name)
                           ->columns;
      @col_map{@columns} = ($from_dq->{right}{to}) x @columns;
    }
    $from_dq = $from_dq->{left};
  }
  die "Don't understand this from"
    unless $from_dq->{type} eq DQ_ALIAS;
  push @alias_dq, $from_dq;

  foreach my $alias (reverse @alias_dq) {
    $alias_list->{$alias->{to}} = $alias;
    my $join_path = $alias->{'dbix-class.join_path'}||[];
    unless (
      $alias->{'dbix-class.is_single'}
      and !grep { $multiplying->{$_} } @$join_path
    ) {
      $multiplying->{$alias->{to}} = $join_path;
    }
    unless ($join_dq{$alias}{outer}) {
      $restricting->{$alias->{to}} ||= $join_path;
    }
  }

  my %to_scan = (
    restricting => [
      ($where ? $conv->_where_to_dq($where) : ()),
      ($attrs->{group_by} ? $conv->_group_by_to_dq($attrs->{group_by}) : ()),
      ($attrs->{having} ? $conv->_where_to_dq($attrs->{having}) : ()),
    ],
    selecting => [
      @{$conv->_select_field_list_to_dq($select)},
      ($attrs->{order_by}
        ? $self->_extract_by_from_order_by(
            $conv->_order_by_to_dq($attrs->{order_by})
          )
        : ())
    ]
  );
  foreach my $type (keys %to_scan) {
    my $this_type = $aliases_by_type->{$type};
    $self->_scan_nodes(
      {
        DQ_IDENTIFIER ,=> sub {
          my ($node) = @_;
          my ($col, $alias) = reverse @{$node->{elements}};
          $alias ||= $col_map{$col};
          if ($alias) {
            $this_type->{$alias} ||=
              $alias_list->{$alias}{'dbix-class.join_path'} || []
          }
        },
        DQ_LITERAL ,=> sub {
          my ($node) = @_;
          if (my $sql = $_[0]->{literal}) {
            while ($sql =~ /(\w+)\.(\w+)/g) {
              if (my $alias_dq = $alias_list->{my $alias = $1}) {
                $this_type->{$alias} ||=
                  $alias_dq->{'dbix-class.join_path'} || []
              }
            }
          }
        },
      },
      @{$to_scan{$type}}
    );
  }
  return $aliases_by_type;
}

sub _extract_by_from_order_by {
  my ($self, $order_dq) = @_;
  my @by;
  while ($order_dq && $order_dq->{type} eq DQ_ORDER) {
    push @by, $order_dq->{by};
    $order_dq = $order_dq->{from};
  }
  return @by;
}

sub _scan_identifiers {
  my ($self, $cb, @queue) = @_;
  $self->_scan_nodes({ DQ_IDENTIFIER ,=> $cb }, @queue);
}

sub _scan_nodes {
  my ($self, $cb_map, @queue) = @_;
  while (my $node = shift @queue) {
    if ($node->{type} and my $cb = $cb_map->{$node->{type}}) {
      $cb->($node);
    }
    push @queue,
      grep ref($_) eq 'HASH',
        map +(ref($_) eq 'ARRAY' ? @$_ : $_),
          @{$node}{grep !/\./, keys %$node};
  }
}

# This is the engine behind { distinct => 1 }
sub _group_over_selection {
  my ($self, $from, $select, $order_by) = @_;
  my $conv = $self->sqla_converter;
  my $from_dq = $conv->_table_to_dq($from);
  my $schema = $self->schema;
  my %col_map;
  {
    my @recurse = $from_dq;
    while (my $next = shift @recurse) {
      if ($next->{type} eq DQ_JOIN) {
        push @recurse, @{$next}{qw(left right)};
        next;
      }
      if ($next->{type} eq DQ_ALIAS) {
        if (my $source_name = $next->{'dbix-class.source_name'}) {
          my @cols = $schema->source($source_name)->columns;
          @col_map{@cols} = ($next->{to}) x @cols;
        }
      }
    }
  }
  my $select_list = $conv->_select_field_list_to_dq($select);
  my (@group_by, %group_seen);
  my %select_aliases;
  foreach my $entry (@$select_list) {
    if ($entry->{type} eq DQ_ALIAS) {
      $select_aliases{$entry->{to}} = 1;
      $entry = $entry->{from}
    }
    if ($entry->{type} eq DQ_IDENTIFIER) {
      push @group_by, \$entry;
      $group_seen{join('.',@{$entry->{elements}})} = 1;
      if (my @el = @{$entry->{elements}} == 1) {
        if (my $alias = $col_map{$el[0]}) {
          $group_seen{join('.',$col_map{$el[0]},$el[0])} = 1;
        }
      }
    } elsif ($entry->{type} eq DQ_LITERAL) {
      # assuming you knew what you were doing, please brace for impact
      push @group_by, \$entry;
    }
  }
  my @leftovers;
  if ($order_by) {
    my $order_dq = $conv->_order_by_to_dq($order_by);
    while ($order_dq) {
      if ($order_dq->{by}{type} eq DQ_IDENTIFIER) {
        my @el = @{$order_dq->{by}{elements}};
        unless(@el == 1 and $select_aliases{$el[0]}) {
          unshift @el, $col_map{$el[0]} if @el == 1 and $col_map{$el[0]};
          push @group_by, \$order_dq->{by}
            unless $group_seen{join('.',@el)};
        }
      } else {
        push @leftovers, $order_dq->{by};
      }
      $order_dq = $order_dq->{from};
    }
  }
  wantarray ? (\@group_by, \@leftovers) : \@group_by;
}

sub _resolve_ident_sources {
  my ($self, $ident) = @_;

  my $alias2source = {};
  my $rs_alias;

  # the reason this is so contrived is that $ident may be a {from}
  # structure, specifying multiple tables to join
  if ( blessed $ident && $ident->isa("DBIx::Class::ResultSource") ) {
    # this is compat mode for insert/update/delete which do not deal with aliases
    $alias2source->{me} = $ident;
    $rs_alias = 'me';
  }
  elsif (ref $ident eq 'ARRAY') {

    for (@$ident) {
      my $tabinfo;
      if (ref $_ eq 'HASH') {
        $tabinfo = $_;
        $rs_alias = $tabinfo->{-alias};
      }
      if (ref $_ eq 'ARRAY' and ref $_->[0] eq 'HASH') {
        $tabinfo = $_->[0];
      }

      $alias2source->{$tabinfo->{-alias}} = $tabinfo->{-rsrc}
        if ($tabinfo->{-rsrc});
    }
  }

  return ($alias2source, $rs_alias);
}

# Takes $ident, \@column_names
#
# returns { $column_name => \%column_info, ... }
# also note: this adds -result_source => $rsrc to the column info
#
# If no columns_names are supplied returns info about *all* columns
# for all sources
sub _resolve_column_info {
  my ($self, $ident, $colnames) = @_;
  my ($alias2src, $root_alias) = $self->_resolve_ident_sources($ident);

  my (%seen_cols, @auto_colnames);

  # compile a global list of column names, to be able to properly
  # disambiguate unqualified column names (if at all possible)
  for my $alias (keys %$alias2src) {
    my $rsrc = $alias2src->{$alias};
    for my $colname ($rsrc->columns) {
      push @{$seen_cols{$colname}}, $alias;
      push @auto_colnames, "$alias.$colname" unless $colnames;
    }
  }

  $colnames ||= [
    @auto_colnames,
    grep { @{$seen_cols{$_}} == 1 } (keys %seen_cols),
  ];

  my (%return, $colinfos);
  foreach my $col (@$colnames) {
    my ($source_alias, $colname) = $col =~ m/^ (?: ([^\.]+) \. )? (.+) $/x;

    # if the column was seen exactly once - we know which rsrc it came from
    $source_alias ||= $seen_cols{$colname}[0]
      if ($seen_cols{$colname} and @{$seen_cols{$colname}} == 1);

    next unless $source_alias;

    my $rsrc = $alias2src->{$source_alias}
      or next;

    $return{$col} = {
      %{
          ( $colinfos->{$source_alias} ||= $rsrc->columns_info )->{$colname}
            ||
          $self->throw_exception(
            "No such column '$colname' on source " . $rsrc->source_name
          );
      },
      -result_source => $rsrc,
      -source_alias => $source_alias,
      -fq_colname => $col eq $colname ? "$source_alias.$col" : $col,
      -colname => $colname,
    };

    $return{"$source_alias.$colname"} = $return{$col} if $col eq $colname;
  }

  return \%return;
}

# The DBIC relationship chaining implementation is pretty simple - every
# new related_relationship is pushed onto the {from} stack, and the {select}
# window simply slides further in. This means that when we count somewhere
# in the middle, we got to make sure that everything in the join chain is an
# actual inner join, otherwise the count will come back with unpredictable
# results (a resultset may be generated with _some_ rows regardless of if
# the relation which the $rs currently selects has rows or not). E.g.
# $artist_rs->cds->count - normally generates:
# SELECT COUNT( * ) FROM artist me LEFT JOIN cd cds ON cds.artist = me.artistid
# which actually returns the number of artists * (number of cds || 1)
#
# So what we do here is crawl {from}, determine if the current alias is at
# the top of the stack, and if not - make sure the chain is inner-joined down
# to the root.
#
sub _inner_join_to_node {
  my ($self, $from, $alias) = @_;

  # subqueries and other oddness are naturally not supported
  return $from if (
    ref $from ne 'ARRAY'
      ||
    @$from <= 1
      ||
    ref $from->[0] ne 'HASH'
      ||
    ! $from->[0]{-alias}
      ||
    $from->[0]{-alias} eq $alias  # this last bit means $alias is the head of $from - nothing to do
  );

  # find the current $alias in the $from structure
  my $switch_branch;
  JOINSCAN:
  for my $j (@{$from}[1 .. $#$from]) {
    if ($j->[0]{-alias} eq $alias) {
      $switch_branch = $j->[0]{-join_path};
      last JOINSCAN;
    }
  }

  # something else went quite wrong
  return $from unless $switch_branch;

  # So it looks like we will have to switch some stuff around.
  # local() is useless here as we will be leaving the scope
  # anyway, and deep cloning is just too fucking expensive
  # So replace the first hashref in the node arrayref manually
  my @new_from = ($from->[0]);
  my $sw_idx = { map { (values %$_), 1 } @$switch_branch }; #there's one k/v per join-path

  for my $j (@{$from}[1 .. $#$from]) {
    my $jalias = $j->[0]{-alias};

    if ($sw_idx->{$jalias}) {
      my %attrs = %{$j->[0]};
      delete $attrs{-join_type};
      push @new_from, [
        \%attrs,
        @{$j}[ 1 .. $#$j ],
      ];
    }
    else {
      push @new_from, $j;
    }
  }

  return \@new_from;
}

sub _order_by_is_stable {
  my ($self, $ident, $order_by, $where) = @_;

  my @ident_dq;
  my $conv = $self->sqla_converter;

  $self->_scan_identifiers(
    sub { push @ident_dq, $_[0] }, $conv->_order_by_to_dq($order_by)
  );

  if ($where) {
    # old _extract_fixed_condition_columns logic
    $self->_scan_nodes({
      DQ_OPERATOR ,=> sub {
        if (($_[0]->{operator}{'SQL.Naive'}||'') eq '=') {
          push @ident_dq,
            grep { $_->{type} eq DQ_IDENTIFIER } @{$_[0]->{args}};
        }
      }
    }, $conv->_where_to_dq($where));
  }

  my $colinfo = $self->_resolve_column_info($ident, [
    map { join('.', @{$_->{elements}}) } @ident_dq
  ]);

  return undef unless keys %$colinfo;

  my $cols_per_src;
  $cols_per_src->{$_->{-source_alias}}{$_->{-colname}} = $_ for values %$colinfo;

  for (values %$cols_per_src) {
    my $src = (values %$_)[0]->{-result_source};
    return 1 if $src->_identifying_column_set($_);
  }

  return undef;
}

1;
