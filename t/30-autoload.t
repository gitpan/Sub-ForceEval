package Frob::Nicate;

use Sub::ForceEval;

use Test::More tests => 2;

our $AUTOLOAD = 'filler string';

ok $Frob::Nicate::AUTOLOAD eq $Sub::ForceEval::AUTOLOAD, "Autoload exported";

sub AUTOLOAD :ForceEval
{
  die "$AUTOLOAD died";
}

__PACKAGE__->aughtta_auto;

pass 'Errors caught';

__END__
