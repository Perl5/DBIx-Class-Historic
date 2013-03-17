package DBIx::Class::SQLMaker::Converter::Oracle;

use Moo;

extends 'DBIx::Class::SQLMaker::Converter';

around _where_hashpair_to_dq => sub {
  my ($orig, $self) = (shift, shift);
  my ($k, $v, $logic) = @_;
  if (ref($v) eq 'HASH' and (keys %$v == 1) and lc((keys %$v)[0]) eq '-prior') {
    my $rhs = $self->_expr_to_dq((values %$v)[0]);
    return $self->_op_to_dq(
      $self->{cmp}, $self->_ident_to_dq($k), $self->_op_to_dq(PRIOR => $rhs)
    );
  } else {
    return $self->$orig(@_);
  }
};

around _apply_to_dq => sub {
  my ($orig, $self) = (shift, shift);
  my ($op, $v) = @_;
  if ($op eq 'PRIOR') {
    return $self->_op_to_dq(PRIOR => $self->_expr_to_dq($v));
  } else {
    return $self->$orig(@_);
  }
};

1;
