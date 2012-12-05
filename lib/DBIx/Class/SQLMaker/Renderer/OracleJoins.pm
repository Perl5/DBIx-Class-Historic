package DBIx::Class::SQLMaker::Renderer::OracleJoins;

sub map_descending (&;@) {
  my ($block, @in) = @_;
  local $_;
  map {
    if (ref($_) eq 'REF' and ref($$_) eq 'HASH') {
      $$_;
    } elsif (ref($_) eq 'HASH') {
      my $mapped = $block->($_);
      local $_;
      +{ map +($_ => &map_descending($block, $mapped->{$_})), keys %$mapped };
    } elsif (ref($_) eq 'ARRAY') {
      [ &map_descending($block, @$_) ]
    } else {
      $_
    }
  } @in;
}

use Data::Query::ExprHelpers;
use Moo;

extends 'Data::Query::Renderer::SQL::Naive';

around render => sub {
  my ($orig, $self) = (shift, shift);
  $self->$orig($self->_oracle_joins_unroll(@_));
};

sub _oracle_joins_unroll {
  my ($self, $dq) = @_;
  ::Dwarn map_descending {
    return $_ unless is_Join;
    return $self->_oracle_joins_mangle_join($_);
  } $dq;
}

sub _oracle_joins_mangle_join {
  my ($self, $dq) = @_;
  my ($mangled, $where) = $self->_oracle_joins_recurse_join($dq);
  Where(
    Operator({ 'SQL.Naive' => 'and' }, $where),
    $mangled
  );
}

sub _oracle_joins_recurse_join {
  my ($self, $dq) = @_;
  die "Can't handle cross join" unless $dq->{on};
  my $mangled = { %$dq };
  my @where;
  my %idents;
  foreach my $side (qw(left right)) {
    if (is_Join $dq->{$side}) {
      ($mangled->{$side}, my ($side_where, $side_idents))
        = $self->_oracle_joins_recurse_join($dq->{$side});
      push @where, $side_where;
      $idents{$side} = $side_idents;
    } else {
      if (is_Identifier($dq->{$side})) {
        $idents{$side} = { join($;, @{$dq->{$side}{elements}}) => 1 };
      } elsif (is_Alias($dq->{$side})) {
        $idents{$side} = { $dq->{$side}{to} => 1 };
      }
      $mangled->{$side} = $self->_oracle_joins_unroll($dq->{side});
    }
  }
  unshift @where, (
    $dq->{outer}
      ? map_descending {
          return $_
            if is_Operator and ($_->{operator}{'SQL.Naive'}||'') eq '(+)';
          return $_ unless is_Identifier;
          die "Can't unroll single part identifiers in on"
            unless @{$_->{elements}} > 1;
          my $check = join($;, @{$_->{elements}}[0..($#{$_->{elements}}-1)]);
          if ($idents{$dq->{outer}}{$check}) {
            return \Operator({ 'SQL.Naive' => '(+)' }, [ $_ ]);
          }
          return $_;
        } $dq->{on}
      : $dq->{on}
  );
  return ($mangled, \@where, { map %{$_||{}}, @idents{qw(left right)} });
}

around _default_simple_ops => sub {
  my ($orig, $self) = (shift, shift);
  +{
    %{$self->$orig(@_)},
    '(+)' => 'unop_reverse',
  };
};

1;
