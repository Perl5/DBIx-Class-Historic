package DBIx::Class::FilterColumn;

use strict;
use warnings;

use base qw/DBIx::Class::Row/;

=head1 NAME

DBIx::Class::FilterColumn - Automatically filter data

=head1 SYNOPSIS

    # In your table classes
    __PACKAGE__->filter_column('column_name', {
        filter => {
		   get    => sub { ... },
		   set    => sub { ... },
		   update => sub { ... },
		  }
    });

=cut

sub filter_column {
  my ($self, $col, $attrs) = @_;
  $self->throw_exception("No such column $col to inflate")
      unless $self->has_column($col);
  $self->throw_exception("inflate_column needs attr hashref")
      unless ref $attrs eq 'HASH';

  
  $self->throw_exception("get must be a CODE ref for $col")
      if(exists $attrs->{get} && ref $attrs->{get} ne 'CODE');
  $self->throw_exception("set must be a CODE ref for $col")
      if(exists $attrs->{set} && ref $attrs->{set} ne 'CODE');
  $self->throw_exception("update must be a CODE ref for $col")
      if(exists $attrs->{update} && ref $attrs->{update} ne 'CODE');
  
  
  $attrs->{update} = $attrs->{set} if not exists $attrs->{update};

  $self->column_info($col)->{_filter_info} = $attrs;
  $self->mk_group_accessors('filtered_column' => $col);
  return 1;
}

sub _filtered_data {
    my ($self, $col, $op, $value) = @_;

    my $column_info = $self->column_info($col);
    $self->throw_exception("$col is not an filtered column")
	unless exists $column_info->{_filter_info};
    
    return $value unless( exists $column_info->{_filter_info}{$op} &&
			  ref $column_info->{_filter_info}{$op} eq 'CODE');
    
    return $column_info->{_filter_info}{$op}->($value, $self);        
}

sub get_filtered_column {
    my ($self, $col) = @_;

    return $self->{_filtered_column}{$col} 
	if exists $self->{_filtered_column}{$col};
    
    return $self->{_filtered_column}{$col} = 
	$self->_filtered_data( $col, 'get', $self->get_column($col) );    
}

sub set_filtered_column {
    my ($self, $col, $value) = @_;
    
    $self->{_filtered_column}{$col} = $self->_filtered_data( $col, 'set', $value );
    $self->set_column($col, $self->{_filtered_column}{$col} );
    return $value;
}

sub update_filtered_column {
    my ($self, $col, $value) = @_;
    
    $self->{_filtered_column}{$col} = $self->_filtered_data( $col, 'update', $value );
    $self->set_column($col, $self->{_filtered_column}{$col} );    
    return $value;
}

sub store_inflated_column {
    my ($self, $col, $value) = @_;

    delete $self->{_column_data}{$col};
    return $self->{_filtered_column}{$col} = $value;
}

sub get_column {
    my ($self, $col) = @_;
    if (  exists $self->{_filtered_column}{$col} && 
	  ! exists $self->{_column_data}{$col}) {
	$self->store_column($col, 
			    $self->_filtered_data($col, 'set', 
						  $self->{_filtered_column}{$col})); 
    }
    
    return $self->next::method($col);
}


sub get_columns {
    my $self = shift;
    if (exists $self->{_inflated_column}) {
	foreach my $col (keys %{$self->{_inflated_column}}) {
	    $self->store_column($col, 
				$self->_filtered_data($col, 'set',
						      $self->{_filtered_column}{$col}))
		unless exists $self->{_column_data}{$col};
	}
    }
    return $self->next::method;
}


sub has_column_loaded {
    my ($self, $col) = @_;
    return 1 if exists $self->{_filtered_column}{$col};
    return $self->next::method($col);
}



sub update {
    my ($class, $attrs, @rest) = @_;
    
    foreach my $key (keys %{$attrs||{}}) {
	if (ref $attrs->{$key} && $class->has_column($key)
	    && exists $class->column_info($key)->{_filter_info}) {
	    $class->update_filtered_column($key, delete $attrs->{$key});
	}
    }
    
    return $class->next::method($attrs, @rest);
}




sub new {
    my ($class, $attrs, @rest) = @_;
    my $filtered;
    
    foreach my $key (keys %{$attrs||{}}) {
	$filtered->{$key} = delete $attrs->{$key} 
	    if ref $attrs->{$key} && $class->has_column($key)
		&& exists $class->column_info($key)->{_filter_info};
    }
    
    my $obj = $class->next::method($attrs, @rest);
    $obj->{_filtered_column} = $filtered if $filtered;
    return $obj;
}

1;
