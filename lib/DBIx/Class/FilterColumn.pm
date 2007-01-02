package DBIx::Class::FilterColumn;

use strict;
use warnings;
use base qw/DBIx::Class::Row/;

sub register_column {
    my ($self, $col, $info, @rest) = @_;
    $self->next::method($col, $info, @rest);
    
    return 1 unless defined($info->{filter}); #nothing to see here
    
    #attrs must be a scalar or array ref and defaults to the $col name
    if( !defined $info->{filter}{attrs} ){
	$info->{filter}{attrs} = [$col];
    } elsif(!ref $info->{filter}{attrs} && $info->{filter}{attrs} ) {
	$info->{filter}{attrs} = [ $info->{filter}{attrs} ];
    } elsif(ref $info->{filter}{attrs} ne 'ARRAY') {
	$self->throw_exception("attrs must be a ARRAY ref or non empty SCALAR for $col");
    } elsif( !@{$info->{filter}{attrs}} ){
	$self->throw_exception("attrs may not be an empty list");
    }
	     
    #get set and update must be code refs if they exist
    $self->throw_exception("get must be a CODE ref for $col")
	if(exists $info->{filter}{get} && ref $info->{filter}{get} ne 'CODE');
    $self->throw_exception("set must be a CODE ref for $col")
	if(exists $info->{filter}{set} && ref $info->{filter}{set} ne 'CODE');
    $self->throw_exception("update must be a CODE ref for $col")
	if(exists $info->{filter}{update} && ref $info->{filter}{update} ne 'CODE');

    #update should be the same as set if not specified otherwise
    $attrs->{update} = $info->{set} if not exists $info->{filter}{update};
    
    $self->column_info($col)->{_filter_info} = $info->{filter};        
    $self->mk_group_accessors('filtered_column' => $col);

    foreach( @{ $info->{filter}{attrs} }){
	$self->throw_exception
	    ("You may not use the same attribute name more than once per table.")
		if(exists $self->{filtered_column_attr_col_map}{$_});

	$self->{_filtered_column_attr_col_map}{$_} = $col;	

	#what should we do if there already is an accessor with that name?!
	#should i intersect column names with attrs and throw an exception
	#but this is register_column. not all the columns and their accessors
	# exist yet. what, oh what should we do about this? assume users 
	#will be halfway smart? dunn dunn dunn
	$self->mk_group_accessors( 'filtered_column_attr' => $_ );
    }

    return 1; 
}


#i hate polluting namespaces. maybe i should inline this ?? 
sub _filtered_data {
    my ($self, $col, $op, $value) = @_;

    my $column_info = $self->column_info($col);
    $self->throw_exception("$col is not an filtered column")
	unless exists $column_info->{_filter_info};
    
    return $value unless( exists $column_info->{_filter_info}{$op} &&
			  ref $column_info->{_filter_info}{$op} eq 'CODE');
    
    return $column_info->{_filter_info}{$op}->($value, $self);        
}


sub get_filtered_column_attr {
    my ($self, $attr) = @_;

    $self->get_filtered_column($self->{_filtered_column_attr_col_map}{$attr} )
	unless exists $self->{_filtered_column_attr}{$attr};    

    return $self->{_filtered_column_attr}{$attr};     	
}

sub set_filtered_column_attr {
    my ($self, $attr, $value) = @_;

    $self->{_filtered_column_attr}->{$attr} = $value;     	
    $self->set_filtered_column( $self->{_filtered_column_attr_col_map}{$attr} );

    return $value;
}

sub set_filtered_column {
    my ($self, $attr, $values) = @_;

    my $attrs      = $self->column_info($col)->{_filter_info}{attrs};        
    my $attr_store = $self->{_filtered_column_attr};
    
    if(ref $values ne 'ARRAY'){
	$values = \@{ $attr_store }{ @$attrs };	
    } elsif(@$attrs == @$values) {
	@{ $attr_store }{ @$attrs } = @$values;
    } else {
	$self->throw_exception("Number of values given do not match expected. Got ".
			       scalar @$values . " expected " . scalar @$attrs);
    }

    $self->set_column( $col, $self->_filtered_data( $col, 'set', $values ));

    return $values;
}

sub get_filtered_column {
    my ($self, $col) = @_;

    my $attrs      = $self->column_info($col)->{_filter_info}{attrs};
    my $attr_store = $self->{_filtered_column_attr};

    return \@{ $attr_store }{ @$attrs }
	if grep { not exists $attr_store->{$_} } @$attrs;
    
    my $values = [ $self->_filtered_data( $col, 'get', $self->get_column($col) ) ];
    @{ $attr_store }{ @$attrs } = @$values;

    return $values;
}


sub store_filtered_column {
    my ($self, $col, $values) = @_;

    my $attrs      = $self->column_info($col)->{_filter_info}{attrs};
    my $attr_store = $self->{_filtered_column_attr};

    delete $self->{_column_data}{$col};
   
    return @{ $attr_store }{ @$attrs } = @$values;
}


sub get_column {
    my ($self, $col) = @_;
    
    my $col_info = $self->column_info($col);
    if( exists $col_info->{_filter_info} ){
	
	my $attrs      = $col_info->{_filter_info}{attrs};
	my $attr_store = $self->{_filtered_column_attr};
	
	#if we dont have col data but we have all the attr pieces
	if( !exists $self->{_column_data}{$col} &&
	    !grep { not exists $attr_store->{$_} } @$attrs ) {
	    
	    $self->store_column
		($col, $self->_filtered_data($col, 'set', 
					     \@{ $attr_store }{ @$attrs } ));
	}
    }
    
    return $self->next::method( $col );
}


sub get_columns {
    my $self = shift;
    
    my $attr_store = $self->{_filtered_column_attr};    
    my @filtered_cols = keys %{ 
	map { $_ => undef } values %{ $self->{_filtered_column_attr_col_map} }
    };
    
    foreach my $col (@filtered_cols){
	next if exists $self->{_column_data}{$col};
	my $attrs = $self->column_info($col)->{_filter_info}{attrs};
	
	$self->store_column
	    ($col, $self->_filtered_data($col, 'set', 
					 \@{ $attr_store }{ @$attrs } ));
    }
    
    return $self->next::method;
}


sub has_column_loaded {
    my ($self, $col) = @_;

    my $col_info   = $self->column_info($col);
    if(exists $col_info->{_filter_info}){
	my $attrs      = $col_info($col)->{_filter_info}{attrs};
	my $attr_store = $self->{_filtered_column_attr};
	
	return 1 
	    unless grep { not exists $attr_store->{$_} } @$attrs;
    }
    
    return $self->next::method($col);
}



sub update {
    my ($class, $attrs, @rest) = @_;
    
    foreach my $key (keys %{$attrs||{}}) {
	if (ref $attrs->{$key} && $class->has_column($key)
	    && exists $class->column_info($key)->{_filter_info}) {

	    $self->{_filtered_column}{$key} = delete $attrs->{$key};   
	    $self->set_column
		($key, 
		 $self->_filtered_data($key,'update',
				       $self->{_filtered_column}{$key}));
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
