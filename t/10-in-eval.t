
use strict;

use Test::More tests => 3;

use Sub::ForceEval;

sub foo :ForceEval { 1 }

my @stack = ( sub { foo } );

for( 1 .. 1024 )
{
  my $prev = $stack[ -1 ];

  push @stack, sub { $prev->() };
}

my $first = $stack[0];

ok eval { foo },          'Works in eval';
ok eval { $first->() } ,  'Works in nested eval';
ok foo,                   'Works without eval';
