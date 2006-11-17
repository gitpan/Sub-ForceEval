
use strict;

use Test::More tests => 2;

use Sub::ForceEval;

my @list = ( 'a' .. 'z' );
my $item = 2;

sub foo :ForceEval { wantarray ? @list : $item }

my @a = foo;

my $b = foo;


ok @list == @a , 'Returns a list';
ok $item == $b , 'Returns a scalar';
