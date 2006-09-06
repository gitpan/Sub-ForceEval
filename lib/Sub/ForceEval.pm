########################################################################
# check for eval on stack at runtime.
########################################################################

########################################################################
# housekeeping
########################################################################

package Sub::ForceEval;

use strict;

use Carp qw( carp cluck );
use Symbol;

use version;

our $VERSION = qv( '0.0.3' );

use Attribute::Handlers;

########################################################################
# package variables
########################################################################

# max stack depth possible in Perl. this is the upper limit for
# caller $x to check for an "(eval" on the stack.

########################################################################
# public sub's
########################################################################

########################################################################
# wrap the attributed sub so that it checks the current stack for an
# eval or dies.
#
# undef &$ref avoids redefinied sub warnings by wiping out the original
# before installing the wrapper. with Symbol this allows warnings to
# be left on throughout the code.

sub UNIVERSAL::ForceEval :ATTR(CODE)
{
  my ( undef, $install, $wrapped ) = @_;

  my $name  = join '::', *{$install}{PACKAGE}, *{$install}{NAME}; 

  no warnings 'redefine';

  *$install
   = sub
  {
    my $array = wantarray;

    my $reply 
    = $array 
    ? [ eval { &$wrapped } ]
    :   eval { &$wrapped }
    ;

    if( @$ )
    {
      # check for an eval: if there is one then die
      # to propagate the exception; otherwise hand
      # back undef.
      #
      # it's up to the caller to handle undef returns.

      my $i = -1;

      while( my $caller = ( caller ++$i )[ 3 ] )
      {
        die $@
        if $caller =~ m{ ^ \(eval\b }x;
      }

      cluck "Missing eval for '$name'", $@;

      return;
    }
    else
    {
      # no need to worry about eval's without a die.

      $array ? @$reply : $reply
    }
  };

}

# keep require happy

1

__END__

=head1 NAME

Sub::ForceEval - runtime cluck if a dying subrutine is not eval-ed.

=head1 VERSION

This document describes Sub::ForceEval version 0.0.1

=head1 SYNOPSIS

    use Sub::ForceEval;

    # if any call to foo dies an eval will be added 
    # at runtime if there isn't already one on the
    # stack.

    sub foo :ForceEval
    {
       ...
    }


    # a bare call to foo() in the main code will cluck
    # about having no eval on the stack and get wrapped
    # on the fly if anything in it dies.

    foo();

    # this works, however, since foo can find that
    # bletch was called from within an eval.

    eval { bletch() };

    sub bletch { bar() }

    sub bar { foo() }


=head1 DESCRIPTION

Subroutines that are marked with the ForceEval attribute 
check at runtime if there is an eval on the stack when
the call dies. If there is an eval on the stack then the
die is propagated to it via die $@; if not then cluck
(see C<Carp>) is called and the die is trapped.

The stack is only checked if something dies, so there
is relatively little overhead in using the attribute.

Note that this inludes anything that dies for any reason
even if the death is not intended as an OO 'exception'.
This can be helpful for long-lived processes that need to
ensure survival. It can also be handy for subs that call
modules which use Fatal: all of the fatalities can be
guaranteed to be gracefully handled.

=head1 INTERFACE

Use the module and add the C<:ForceEval> attribute to a 
subroutine:

    use Sub::ForceEval;

    sub foo :ForceEval { ...}


=head1 DIAGNOSTICS

=over 4

=item "Missing eval for '$name'", $@

An C<:ForceEval> subroutine was called from a context 
where exceptions would not be caught by any surrounding 
C<eval>. This uses Carp::cluck to complain about the fact
and keeps going.

=back

=head1 CONFIGURATION AND ENVIRONMENT

Sub::ForceEval requires no configuration files or environment
variables.


=head1 DEPENDENCIES

  strict

  Carp

  Symbol

  version

  Attribute::Handlers 


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

This is nearly impossible to test since detecting that 
the module incorrectly detected an existing eval requires
running it in an eval...

Please report any bugs or feature requests to
C<bug-sub-ForceEval@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 AUTHORS

Steven Lembark <lembark@wrkhors.com>
Damian Conway


=head1 LICENCE AND COPYRIGHT

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES. 
