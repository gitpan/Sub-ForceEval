########################################################################
# check for eval on stack at runtime;
# die with optionally blessed exception.
########################################################################

########################################################################
# housekeeping
########################################################################

package Sub::ForceEval;

use strict;
no warnings 'redefine';

use Carp qw( croak carp cluck );
use Symbol;

use version;

our $VERSION = qv( '0.4.3' );

use Attribute::Handlers;

########################################################################
# package variables
########################################################################

# default $@ handlers keyed by package name; updated in import.

my %blesserz = ();

########################################################################
# local utility subs
########################################################################

########################################################################
# default is to simply localize $@ for the caller.
# otherwise, sanity chech $@ for already being some
# class compatable with the requested package and 
# bless it if necesssary.

my $default_handler = sub { @_ };

my $generate_handler
= sub
{
    # generate handlers to bless $@.

    my ( $handler ) = @_
    or return $default_handler;

    if( my ( $class, $method ) = $handler =~ m{ ^ ( .+ ) -> ( \w+ ) $ }x )
    {
      sub
      {
        if( my $sub = $class->can( $method ) )
        {
          unshift @_, $class;

          goto &$sub
        }
        else
        {
          warn "Warning: Class '$class' cannot '$method'";

          goto &$default_handler
        }
      }
    }
    elsif( my ( $pack, $name ) = $handler =~ m{ ^ ( .+ ) :: ( \w+ ) $ }x )
    {
      sub
      {
        if( my $sub = $pack->can( $name ) )
        {
          goto &$sub
        }
        else
        {
          warn "Warning: Package '$pack' cannot '$name'";

          goto &$default_handler
        }
      }
    }
    else
    {
      warn "Warning: No method or sub name in '$handler'";

      $default_handler
    }
};

########################################################################
# this does the real meat of wrapping the original: coderef's and 
# code are handled the same basic way.

our $AUTOLOAD = '';

my $install_handler 
= sub
{
  my ( undef, $install, $wrapped, undef, $handler ) = @_;

  my $pkg   = *{$install}{PACKAGE};

  my $name  = join '::', $pkg, *{$install}{NAME};

  # use the caller's method if requested, otherwise
  # take the package's default (which may be $default_blesser).

  # make sure that the caller's AUTOLOAD scalar
  # is avaiable here when the time comes.

  if( *{$install}{ NAME } eq 'AUTOLOAD' )
  {
    my $pkg_autoload = qualify_to_ref 'AUTOLOAD', $pkg;

    *{ $pkg_autoload } = \$AUTOLOAD;
  }

  my $blesser
  = $handler
  ? $generate_handler->( $handler )
  : $blesserz{ $pkg }
  ;

  *$install
  = sub
  {
    no strict 'refs';

    local *{ $pkg . 'AUTOLOAD' } = \$AUTOLOAD;

    my $reply   = '';

    # make sure the wrapped sub sees the same
    # context: void, scalar, or array.

    if( wantarray )
    {
        $reply  = [ eval { &$wrapped } ]
    }
    elsif( defined wantarray )
    {
        $reply  =   eval { &$wrapped }
    }
    else
    {
        eval { &$wrapped }
    }

    if( $@ )
    {
        my $i = -1;

        while( my $caller = ( caller ++$i )[ 3 ] )
        {
            # re-throw the error if someone is 
            # out there to get it (i.e., if the 
            # caller string at that level 
            # begings with 'eval').

            next if index $caller, '(eval';

            die $blesser->( $@ )
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

      return unless defined wantarray;

      wantarray ? @$reply : $reply
    }
  };
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

    # discard this class

    shift;

    $blesserz{ $caller } = $generate_handler->( @_ );

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

sub UNIVERSAL::ForceEval : ATTR(CODE)
{
  goto &$install_handler
}

sub UNIVERSAL::ForceEval : ATTR(SCALAR)
{
  goto &$install_handler
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
    # Dive::Dive->dive( $@ ).

    package MyClass;

    use Sub::ForceEval qw( My::Class::Default->constructor );

    sub marine :ForceEval( 'Dive::Dive->dive' );

    # then again, you may just want to record or
    # tidy up the message. in this case, you can pass
    # in a function without the '->' separator and 
    # it'll be callsed as function( $@ ).

    use Sub::ForceEval qw( Some::Package::function );


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

Each package that uses ForceEval can have its own
setting. There is currently no way to set a global
default.

=over 4

=item Package default exception

Passing a constructor to "use" will wrap all $@ via
the constructor for subroutines in that package:

    use Sub::ForceEval qw( Exceptional::Class->construct );

The literal '->' is text, it does not mean that the
constructor needs to return a subref.

This will be broken into $class of Exceptional::Class
and method of "construct", which are then called as:
    
    die $class->$method( $@ );

so that whatever they return will be passed as the
exception.

=item Subroutine-specific exception

Passing a constructor to the ForceEval attribute will use
that instead of any package default:

    sub frobnicate :ForceEval qw( Exceptional::File->handler )
    {
        ...
    }

leaves $class and $method for the subroutine set to 
"Exceptional::File" and "handler".

=back

=head2 Filtered exceptions

If all you want to do is log or munge the errors, 
then a simple subroutine may do just as well. These
are used via:

  use Sub::ForceEval qw( My::function );

or

  sub foo :ForceEval qw( Some::Package::munge_error )
  {
    ...
  }

Functions are checked via $package->can( $name ),
defaulting to a stub that passes back $@ as-is
with a warning that "$package cannot $name".

=head2 wrapping AUTOLOAD and friends.

=over 4

=item using "sub"

Due to the handling by Attribute::Handlers, adding 
ForceEval to AUTOLOAD, DESTROY, BEGIN, CHECK, or 
INIT blocks requires that they have a 'sub' prefix
in the code.

Working code:

  sub AUTOLOAD  :ForceEval
  {
    ...
  }

This will fail since it lacks the "sub":

  AUTOLOAD  :ForceEval
  {
    ...
  }

=item $AUTOLOAD

The autoload in Sub::ForceEval is installed into
the Eval'ed sub's package. This means that all
AUTOLOADS that use ForceEval in the program will
share a single $AUTOLOAD. This is not normally an
issue since only one AUTOLOAD at a time is called
and daisy-chaining them depends on their having a 
common value anyway. 

=back

=head1 DIAGNOSTICS

=over 4

=item "Missing eval for '$name'", $@

An C<:ForceEval> subroutine was called from a context 
where exceptions would not be caught by any surrounding 
C<eval>. This uses Carp::cluck to complain about the fact
and keeps going.

=item "Warning: 'Package <package>' cannot '<name>'

=item "Warning: 'Class <package>' cannot '<name>'

Breaking up the handler argument on '->' or the final '::' 
gives a package and name. These are checked via 

  $package->can( $name )

at runtime, prior to dispatch. If the given package does 
not have the name in it (or one of its base classes in OO) 
then Sub::ForceEval logs the warning and returns $@ as-is.

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
