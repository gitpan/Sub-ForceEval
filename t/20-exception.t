
package Handle::Error;

sub oops { join ' ', 'oops:', @_, "\n" }
sub baah { join ' ', 'baah:', @_, "\n" }

package main;

use strict;

use Sub::ForceEval  qw( Handle::Error->oops );

use Test::More tests => 3;

sub foo :ForceEval
{ die "foo" }

sub bar :ForceEval(Handle::Error->baah)
{ die "bar" }

print STDERR "\nDie with eval:\n";

eval { foo };

like $@, qr/^oops: Handle::Error foo/;

eval { bar };

like $@, qr/^baah: Handle::Error bar/;

# die shouldn't stop execution

print STDERR "\nDie outside eval:\n";

foo;
bar;

pass 'Errors caught';

__END__
