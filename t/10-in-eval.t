
use strict;

use Test::More tests => 6;

use Sub::ForceEval;

sub foo :ForceEval { 'frobnicate' }

my @stack = ( sub { foo } );

for( 1 .. 1024 )
{
  my $prev = $stack[ -1 ];

  push @stack, sub { $prev->() };
}

my $first = $stack[ 0];

my $a = foo;
my $b = $stack[ 0]->();
my $c = $stack[-1]->();

ok $a eq 'frobnicate',    'Sub call returns expected result';
ok $b eq $a,              'First stack Returns expected result';
ok $c eq $a,              'Last stack Returns expected result';

my $d = eval { foo };          
my $e = eval { $first->() } ;
my $f = foo;

ok $d eq $a, 'Works in eval';
ok $e eq $a, 'Works in nested eval';
ok $f eq $a, 'Works without eval';
