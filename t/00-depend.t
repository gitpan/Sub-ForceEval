
use strict;

use Test::More;

my @dependz =
qw
(
  strict
  Carp
  Symbol
  version
  Attribute::Handlers
);

plan tests => scalar @dependz;

use_ok $_ for @dependz;
