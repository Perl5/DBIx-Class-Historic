package # hide from PAUSE
  DBIx::Class::_Types;

use strict;
use warnings;
use Carp qw(confess);

use Path::Tiny;
use Sub::Name;
use Scalar::Util qw(blessed looks_like_number reftype);

sub import {
  my ($package, @methods) = @_;
  my $caller = caller;
  for my $method (@methods) {
    $package->can($method) or confess "$package does not export $method";
    my $coerce = $package->can("coerce_$method");
    my $full_method = "${caller}::${method}";
    { no strict;
      *{$full_method} = subname $full_method => sub {
        my %args = @_;
        my $check = sub { my $value = shift; &{$method}($value, %args) };
        ($coerce && $args{coerce} && wantarray)
          ? ( $check, coerce => $coerce )
          : $check;
      };
    }
  }
}

sub error {
  my ($default, $value, %args) = @_;
  if(my $err = $args{err}) {
    confess $err->($value);
  } else {
    confess $default;
  }
}

sub Str {
  error("Value $_[0] must be a string")
    unless Defined(@_) && !ref $_[0];
}

sub Path {
  error("Value $_[0] must be a Path::Tiny")
    unless Object(@_) && $_[0]->isa("Path::Tiny");
}

sub coerce_Path { path($_[0]) }

sub Defined {
  error("Value $_[0] must be Defined", @_)
    unless defined($_[0]);
}

sub UnDefined {
  error("Value $_[0] must be UnDefined", @_)
    unless !defined($_[0]);
}

sub Bool {
  error("$_[0] is not a valid Boolean", @_)
    unless(!defined($_[0]) || $_[0] eq "" || "$_[0]" eq '1' || "$_[0]" eq '0');
}

sub Number {
  error("weight must be a Number greater than or equal to 0, not $_[0]", @_)
    unless(Defined(@_) && looks_like_number($_[0]));
}

sub Integer {
  error("$_[0] must be an Integer", @_)
    unless(Number(@_) && (int($_[0]) == $_[0]));
}

sub HashRef {
  error("$_[0] must be a HashRef", @_)
    unless(Defined(@_) && (reftype($_[0]) eq 'HASH'));
}

sub _json_to_data {
  my ($json_str) = @_;
  require JSON::Any;
  JSON::Any->import(qw(DWIW XS JSON));
  my $json = JSON::Any->new(allow_barekey => 1, allow_singlequote => 1, relaxed=>1);
  my $ret = $json->jsonToObj($json_str);
  return $ret;
}

sub DBICHashRef {
  HashRef(@_);
}

sub coerce_DBICHashRef {
  _json_to_data(@_);
}

sub DBICConnectInfo {
  ArrayRef(@_);
}

sub coerce_DBICConnectInfo {
  reftype $_[0] eq 'HashRef' ? [ $_[0] ] : _json_to_data(@_);
}

sub PositiveNumber {
  error("value must be a Number greater than or equal to 0, not $_[0]", @_)
    unless(Number(@_) && ($_[0] >= 0));
}

sub PositiveInteger {
  error("Value must be a Number greater than or equal to 0, not $_[0]", @_)
    unless(Integer(@_) && ($_[0] >= 0));
}

sub ClassName {
  error("$_[0] is not a loaded Class", @_)
    unless(Defined(@_) && ($_[0]->can('can')));
}

sub Object {
  error("Value is not an Object", @_)
    unless(Defined(@_) && blessed($_[0]));
}

sub DBICStorageDBI {
  error("Need an Object of type DBIx::Class::Storage::DBI, not ".ref($_[0]), @_)
    unless(Object(@_) && ($_[0]->isa('DBIx::Class::Storage::DBI')));
}

sub DBICStorageDBIReplicatedPool {
  error("Need an Object of type DBIx::Class::Storage::DBI::Replicated::Pool, not ".ref($_[0]), @_)
    unless(Object(@_) && ($_[0]->isa('DBIx::Class::Storage::DBI::Replicated::Pool')));
}

sub DBICSchema {
  error("Need an Object of type DBIx::Class::Schema, not ".ref($_[0]), @_)
    unless(Object(@_) && ($_[0]->isa('DBIx::Class::Schema')));
}

sub DoesDBICStorageReplicatedBalancer {
  error("$_[0] does not do DBIx::Class::Storage::DBI::Replicated::Balancer", @_)
    unless(Object(@_) && $_[0]->does('DBIx::Class::Storage::DBI::Replicated::Balancer') );
}

1;

