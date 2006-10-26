########################################################################
# check for eval on stack at runtime;
# die with optionally blessed exception.
########################################################################

########################################################################
# housekeeping
########################################################################

package Sub::ForceEval;

use strict;

use Carp qw( croak carp cluck );
use Symbol;

use version;

our $VERSION = qv( '0.2.1' );

use Attribute::Handlers;

########################################################################
# package variables
########################################################################

my %blesserz = ();

########################################################################
# local utility subs
########################################################################

########################################################################
# default is to simply localize $@ for the caller.
# otherwise, sanity chech $@ for already being some
# class compatable with the requested package and 
# bless it if necesssary.

my $default_exception = sub { $@ };

my $bless_exception
= sub
{
    # bless $@ before re-throwing.

    my ( $method ) = @_;

    my ( $pack, $name )
    = $method =~ m{^ ( .+ ) :: ( \w+ ) $}x
    or die "Bogus Sub::ForceEval: no package and method in '$method'";

    my $sub = $pack->can( $name )
    or croak "Bogus Sub::ForceEval: '$pack' cannot '$name'";

    sub
    {
      ref $@ && $@->isa( $pack )
      ? $@
      : $pack->$sub( $@ )
    }
};

########################################################################
# public sub's
########################################################################

########################################################################
# caller can specify a method to pre-process $@ before
# rethrowing -- probably a constructor for OO-$@ handling.

sub import
{
    my $caller = caller;

    my ( undef, $method ) = @_;

    $blesserz{ $caller } 
    = $method
    ? $bless_exception->( $method )
    : $default_exception
    ;

    0
}

########################################################################
# wrap the attributed sub so that it checks the current stack for an
# eval or dies.
#
# undef &$ref avoids redefinied sub warnings by wiping out the original
# before installing the wrapper. with Symbol this allows warnings to
# be left on throughout the code.
#
# Note: assigning *__ANON__ gives this anonymous sub if we 
# have to report any errors.

sub UNIVERSAL::ForceEval :ATTR(CODE)
{
  my ( undef, $install, $wrapped, undef, $method ) = @_;

  my $pkg   = *{$install}{PACKAGE};

  my $name  = join '::', $pkg, *{$install}{NAME};

  # use the caller's method if requested, otherwise
  # take the package's default (which may be $default_blesser).

  my $blesser
  = $method
  ? $bless_exception->( $method )
  : $blesserz{ $pkg }
  ;

  no warnings 'redefine';

  *$install
  = sub
  {
    wantarray
    ? my @reply = eval { &$wrapped }
    : my $reply = eval { &$wrapped }
    ;

    if( $@ )
    {
        my $i = -1;

        while( my $caller = ( caller ++$i )[ 3 ] )
        {
            # re-throw the error if someone is out 
            # there to get it.

            die $blesser->( $@ )
            if $caller =~ m{ ^ \(eval\b }x;
        }

        # ran out of stack: cluck about it, with a legit
        # name as the source.

        local *__ANON__ = $name;

        my $exception
        = ref $@                       ? 'exception object'
        : $@ =~ m{(.*) at \S+ line .*} ? "'$1'"
        :                                "'$@'"
        ;

        cluck "Missing eval for '$name' (died with: $exception) caught";

        return
    }
    else
    {
      # no exception: just hand back the data;

      wantarray ? @reply : $reply
    }
  };
}

# keep require happy

1

__END__

=head1 NAME

Sub::ForceEval - eval subroutines, re-throw exceptions
if there is an eval; otherwise cluck and return undef.

=head1 SYNOPSIS
  
    # you may just want your death recorded...
    #
    # if foo dies in an eval then $@ will be re-thrown, 
    # otherwise foo will cluck, return undef, and keep 
    # going.

    use Sub::ForceEval;

    sub foo :ForceEval
    {
       ...
    }

    # a bare call to foo() in the main code will cluck.

    foo();

    # the exception is re-thrown here, however, since
    # bletch was called from within an eval.

    eval { bletch() };

    sub bletch { bar() }

    sub bar { foo() }


    # ... or you may want an exceptional death.
    #
    # the default in MyClass is to have ForceEval 
    # call My::Class::Default->constructor( $@ )
    # before re-throwing, marine re-throws 
    # Local::Fixup->handler( $@ ).

    package MyClass;

    use Sub::ForceEval qw( My::Class::Default::constructor );

    sub marine :ForceEval( 'Local::Fixup::handler' );


=head1 DESCRIPTION

Subroutines that are marked with the ForceEval attribute 
check at runtime if there is an eval on the stack when
the call dies. If an eval is found then the die is 
propagated to it via die $@; if not then cluck (see 
C<Carp>) is called and the die is trapped.

The stack is only checked if something dies, so there
is relatively little overhead in using the attribute:
just an eval and intermediate storage of the return
values.

Note that this inludes anything that dies for any reason
even if the death is not intended as an OO 'exception'.
This can be helpful for long-lived processes that need to
ensure survival. It can also be handy for subs that call
modules which use Fatal: all of the fatalities can be
guaranteed to be gracefully handled.

If exception objects are preferred to flat $@ values then
a constructor can be provided with the use. This will
be broken into class and method portions and called to 
construct an object from the exception; individual subs
can also provide a constructor. 

=head1 INTERFACE

=head2 Un-blessed exceptions (default)

Use the module and add the C<:ForceEval> attribute to a 
subroutine:

    use Sub::ForceEval;

    sub foo :ForceEval { ...}

If foo dies within an eval then "die $@" is used
to propagate the exception.

=head2 Blessed exceptions (optional)

=over 4

=item Package default exception

Passing a constructor to "use" will wrap all $@ via
the constructor for subroutines in that package:

    use Sub::ForceEval qw( Exceptional::Class::construct );

This will be broken into $class of Exceptional::Class
and method of "construct", which are then called as:
    
    die $class->$method( $@ );

This is a per-package setting (i.e., using it in one 
package does not affect other packages to use it with
ForceEval).

=item Subroutine-specific exception

Passing a constructor to the ForceEval attribute will use
that instead of any package default:

    sub frobnicate :ForceEval qw( Exceptional::File::handler )
    {
        ...
    }

leaves $class and $method for the subroutine set to 
"Exceptional::File" and "handler".


=back

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

Some parts of this are impossible to test since detecting
that the module incorrectly detected an existing eval requires
running it in an eval.

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
