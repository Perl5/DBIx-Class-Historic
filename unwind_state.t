use warnings;
use strict;

# each object runs 3 tests on destroy
# 8 regular objects, 5 global variables
use Test::More tests => 8*3 + 5*3;

use constant {
  REGULAR_GC => 'T.B.D. regular GC constant',
  EXCJUMP_GC => 'T.B.D. exception-triggered GC constant',
};

our $U = 'N/A';  # temporary varname for the proof of conept

# regular GC
UG->singleton;
{
  my $g1 = UG->new(REGULAR_GC);
}

# forced GC
UG->singleton;
{
  my $g1 = UG->new(REGULAR_GC);
  undef ($g1);
}

# normal GC mixed with an exception-triggered GC
UG->singleton;
{
  my $g1 = UG->new(REGULAR_GC);

  eval {
    my $g2 = UG->new(EXCJUMP_GC);
    die 'uh-oh';
  };
}

# GC triggered by lower-scope exception
UG->singleton;
{
  my $g1 = UG->new(REGULAR_GC);

  eval {
    {
      my $g2 = UG->new(EXCJUMP_GC);
      {
        die 'foo';
      }
    }
  };
}

# GC triggered by lower-stack exception
sub call_throw {
  my $g1 = UG->new(EXCJUMP_GC);
  throw();
}
sub throw {
  die 'boom';
}

UG->singleton;
{
  my $g1 = UG->new(REGULAR_GC);
  eval { call_throw() };
}

#######
#######

{
  package UG;

  sub new {
    my $class = shift;

    die "new() requires an 'expected destruction state' arg\n"
      unless @_;

    my $state = shift;

    bless (\$state, $class);
  }

  sub singleton {
    $::global_guard ||= shift->new(::REGULAR_GC);
  }

  sub DESTROY {
    {
      my $sub = UG::Sub->new(::REGULAR_GC);
    }
    ::is ( $::U, ${ shift() } );
    eval {
      my $sub = UG::Sub->new(::EXCJUMP_GC);
      die 'Crap'; # even if not available in DESTROY should signal that $sub above was GCed due to a jump
    };

    undef $::global_guard;
  }
}

{
  package UG::Sub;

  use base qw/UG/;

  sub DESTROY {
    ::is ( $::U, ${ shift() } );
  }
}
