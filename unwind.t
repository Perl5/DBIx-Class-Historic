use warnings;
use strict;
use Data::Dumper;

use constant {
  REGULAR => 0,
  EXCJUMP => 1,
};

our @U_STACK = REGULAR;

# make a mock caller that returns $U_STACK[$frame] as $frame[11]
BEGIN {
  *CORE::GLOBAL::caller = sub {
    my $f = $_[0] || 0;
    my @res = CORE::caller ($f + 1)
      or return ();

    # we did not add a frame here, thus $f, not $f+1
    return @_ ? (@res, $U_STACK[$f] ) : (@res[0..2]);
  };
}

# use our own cluck that prefiex (caller($f))[11]
sub cluck {
  # extra frame for cluck() itself
  local @U_STACK = (REGULAR, @U_STACK);

  my $text = shift || "something's wrong";
  my @finfo = caller(0);
  warn ("\n[$finfo[11]] $text at $finfo[1] line $finfo[2]\n");

  my $frame = 1;
  while (my @finfo = caller($frame++) ) {
    warn ("[$finfo[11]] \t$finfo[3] called at $finfo[1] line $finfo[2]\n");
  }
}

### the simple case
{
  my $g1 = Guard->new( REGULAR );

  eval {
    local @U_STACK = (REGULAR, @U_STACK);

    my $g2 = Guard->new( EXCJUMP, sub {

      local @U_STACK = (REGULAR, @U_STACK);

      eval {
        local @U_STACK = (REGULAR, @U_STACK);

        my $g3 = Guard->new( EXCJUMP );
        die 'ugh';
      };

    });

    die 'uh-oh';
  };
}


### the convoluted case
our $singleton = Guard->new( REGULAR, sub {
  my $exp = shift->{exp};
  local @U_STACK = ($exp, @U_STACK);

  my $g1 = Guard->new( REGULAR );

  eval {
    local @U_STACK = ($exp, @U_STACK);

    my $g2 = Guard->new( EXCJUMP, sub {
      local @U_STACK = (REGULAR, @U_STACK);

      eval {
        local @U_STACK = (REGULAR, @U_STACK);

        my $g3 = Guard->new( EXCJUMP );
        die 'ugh';
      };
    });

    die 'ouch';
  };
});

{
  my $g1 = Guard->new( REGULAR );

  eval {
    local @U_STACK = (REGULAR, @U_STACK);

    my $g2 = Guard->new( EXCJUMP, sub {

      local @U_STACK = (REGULAR, @U_STACK);
      undef $::singleton

    } );
    die 'uh-oh';
  };
}


{
  package Guard;

  use warnings;
  use strict;

  use Scalar::Util qw/refaddr/;

  use Data::Dumper;

  use overload '""' => 'stringify';

  sub new {
    my ($class, $expected_state, $destructor_callback) = @_;
    local @U_STACK = (::REGULAR, @U_STACK);

    die "Need an expected state" unless defined $expected_state;

    my $obj = bless({
      exp => $expected_state,
      code => $destructor_callback,
      line => (CORE::caller)[2],
    }, $class );

    ::cluck ("Instantiated $obj");

    return $obj;
  }

  sub stringify {
    my $self = shift;
    return sprintf ('Guard[0x%x][instline:%d]',
      refaddr $self, $self->{line},
    );
  }

  sub DESTROY {
    my $self = shift;
    local @U_STACK = ($self->{exp}, @U_STACK);
    ::cluck ("Begin destruction of $self");
    $self->{code}->($self) if $self->{code};
  }
}
