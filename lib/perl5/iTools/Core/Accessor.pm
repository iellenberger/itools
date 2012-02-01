package iTools::Core::Accessor;
our $VERSION = 0.3;

use Carp qw(confess);
use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging

use strict;
use warnings;

# === Class and Version =====================================================
sub CLASS { ref shift }

# === Master get/set method =================================================
sub _var {
	my ($self, $key) = (shift, shift);

	# --- get the value ---
	unless (@_) {
		return $self->{$key} if exists $self->{$key};
		return undef;
	}

	# --- delete the key if value = undef ---
	unless (defined $_[0]) {
		my $value = $self->{$key};  # store the old value
		delete $self->{$key};       # delete the key
		return $value;              # return the old value
	}

	# --- set and return the value ---
	return $self->{$key} = shift;
}

# --- idempotent version of var ---
sub _ivar {
	my ($self, $key) = (shift, shift);

	# --- get the value ---
	return $self->_var($key) unless @_;

	# --- don't set value if it already exists ---
	return $self->{$key} if exists $self->{$key};

	# --- set and return the value ---
	return $self->{$key} = shift;
}

# --- var w/ default values or code block ---
sub _varDefault {
	my ($self, $default, $key) = (shift, shift, shift);

	# --- set or reset the value ---
	if (@_) {
		# --- set the value and return ---
		return $self->_var($key => @_) if defined $_[0];
		# --- reset the value, continue to get default ---
		$self->_var($key => undef);
	}

	# --- get the current value ---
	my $value = $self->_var($key);
	# --- return the value if it's defined ---
	return $value if defined $value;

	# --- get the default value ---
	if (ref $default eq 'CODE') { $value = &$default($self, $key) }  # default is code
	else                        { $value = $default }                # default is scalar

	# --- return the default value ---
	return $value;
}

# --- array accessor ---
sub _varArray {
	my ($self, $key) = (shift, shift);

	# --- throw an error if the value exists and is not an array ---
	confess "\nRuntime error accessing the instance variable '$key' for the package ". ref($self) .".\n".
	    "  An attempt was made to access the instance variable '$key' using the _varArray() method,\n".
		 "    but the value is not an array.  Did you mix _var() and _varArray() or mess up the value\n".
		 "    by accessing the instance variable directly?\n".
		 "  If you need assistance using _varArray(), see the ". __PACKAGE__ ."(3pm) manpage.\n\n"
		if exists $self->{$key} && ref $self->{$key} ne 'ARRAY';

	# --- get the value ---
   unless (@_) {
		return @{$self->{$key}} if exists $self->{$key};
		return;
	}

	# --- delete the key if only param is undef ---
	if (@_ <= 1 && !defined $_[0]) {
		my @values = @{$self->{$key}} if exists $self->{$key};  # store the old values
		delete $self->{$key};           # delete the key
		return @values;                 # return the old values
	}

	# --- set and return the value ---
	$self->{$key} = [ @_ ];
	return @{$self->{$key}};
}

1;

=head1 NAME

iTools::Core::Accessor - accessor extension for objects

=head1 SYNOPSIS

 package My::Name;
 use base 'iTools::Core::Accessor';

 sub name { shift->_var(theName => @_) }

 ...

 my $obj = new My::Name;
 $obj->name('JimBob');
 my $name = $obj->name;
 my $class = $obj->CLASS;

=head1 DESCRIPTION

iTools::Core::Accessor is an inheritable extension that makes creating and managing read/write accessors easy.

This class provides several interfaces for managing variables:
_var(), _ivar(), _varDefault() and _varArray().
It also provides a convienience function in C<CLASS()>.

=head2 Defining a Single Accessor using _var() and _varDefault()

_var() is a protected method that manages values in an object.
The actual code (for those too lazy to actually crack open the module) looks like this:

  sub _var {
    my ($self, $key) = (shift, shift);

    # --- get the value ---
    unless (@_) {
      return $self->{$key} if exists $self->{$key};
      return undef;
    }

    # --- deleting a key if value = undef ---
    unless (defined $_[0]) {
      my $value = $self->{$key};  # store the old value
      delete $self->{$key};       # delete the key
      return $value;              # return the old value
    }

    # --- set and return the value ---
    return $self->{$key} = shift;
  }

This implementation addresses the following problems commonly associated with accessors:

=over 2

=item Compact and Readable Code:

Implementing everything required to properly manage accessor values can create code that is long and difficult to maintain (especially if you have lots of accessors).
_var() shortens the implementation of an accessor down to a single line:

  sub name { shift->_var(theName => @_) }

=item Separate Set and Get Methods:

It is common practice to create a pair of accessors for each variable, but this is Perl and we can be more creative than that!
_var() allows you to create a single method to do both.

On the other and, if you REALLY want to have separate methods or only want to implement limited functionality, here are some examples:

  sub setName    { shift->_var(theName => @_)    }
  sub getName    { shift->_var('theName')        }
  sub deleteName { shift->_var(theName => undef) }

=item Default Values and Protection Against 'undef':

You may want to ensure that an accessor never returns 'undef' or returns a default value.
The _varDefault() method addresses both of those concerns:

  # --- return empty string instead of undef ---
  sub name { shift->_varDefault('', theName => @_) }

  # --- return a default value ---
  sub name { shift->_varDefault('George', theName => @_) }

_varDefault() also allows you to use the return value of a code block as the default value:

  # --- return current epoch time as the name ---
  sub name { shift->_varDefault(sub { time }, theName => @_) }

=item Array Accessors:

No more pain-in-the-ass array dereferencing - Woohoo!

  # --- store a list of names ---
  sub names { shift->_varArray(allNames => @_) }

=item Abstraction:

Abstracting a class's hash values is simply good practice.
This practice also allows you to use variable names that will not clash with other super/sub classes.
It is good to choose names that are likely to be unique across the object tree:

  sub name { shift->_var('__My::Class_theName' => @_) }

=item Idempotency:

If you like the way Java loads properties, you need a good slap to the back of the head.
Unfortunately it is sometimes a necessary evil.

You can implement a idempotent version of the accessor like-a soooo:

  sub name { shift->_ivar(theName => @_) }

=back

=head3 Examples

Start by defining and accessor in your code:

  sub name { shift->_var(theName => @_) }

When you use the accessor, the return value depends on what you pass to it.

  my $obj = new My::Name;       # Constructor
  my $foo = $obj->name;         # $foo = undef,
                                #    $obj->{theName} does not exist
  $foo = $obj->name('Ingmar');  # $foo = $obj->{theName} = 'Ingmar'
  $foo = $obj->name;            # $foo = 'Ingmar'
  $foo = $obj->name('');        # $foo = $obj->{theName} = ''
  $foo = $obj->name(0);         # $foo = $obj->{theName} = 0;
  $foo = $obj->name(undef)      # $foo = 0 (last value),
                                #    $obj->{theName} deleted

_varArray() extends this functionality to arrays:

  my @bar = $obj->names('Bob', 'Jim');     # combined array set/get
  @bar = $obj->names($obj->names, 'Joe');  # extending the array
  $obj->names(undef);                      # delete

=head2 Convienience Methods

The CLASS() method returns the class name for the object.
I am not sure what inspired me to put this here considering all it does is C<ref $self>.
Expect this to be deprcated in the future.

=head1 METHODS

=over 2

=item $obj->B<_var>(I<KEY> [=> I<VALUE>])

The universal accessor.
Sets $B<obj>->{I<KEY>} to I<VALUE>.
See examples above for usage.

The chart below maps the function of the _var() method:

=begin man

.Vb 7
\&
\&    _____inputs_____  _____________outputs______________
\&    \fIKEY\fR      \fIVALUE\fR    \f(CW$obj\fR\->{\fIKEY\fR}   \fBreturn\fRs
\&    \fB-------  -------  ------------  --------------------\fR
\&    any      none     no change     \f(CW$obj\fR\->{\fIKEY\fR} or \fBundef\fR
\&    any      \fBdefined\fR  set to \fIVALUE\fR  \fIVALUE\fR
\&    \fBexists\fR   \fBundef\fR    \fBdelete\fRd       old \f(CW$obj\fR\->{\fIKEY\fR}
\&    !\fBexists\fR  \fBundef\fR    no change     \fBundef\fR
.Ve

=end man

It is important that @_ be that last parameter passed to _var().
Not doing do will produce results you did not expect.
If you implement _var() as follows:

  sub name { shift->_var(theName => shift) }

and then try a get:

  my $foo = $obj->name;

Perl will ALWAYS pass three parameters to the _vars() method ($obj, 'theName' and undef).
This results in the accessor's I<VALUE> being cleared after each 'get'.
The correct implementation is:

  sub name { shift->_var(theName => @_) }

=item $obj->B<_ivar>(I<KEY> [=> I<VALUE>])

Same as _var() except that it is idempotent.

=item $obj->B<_varArray>(I<KEY> [=> I<VALUE>[, ...]])

Works just like _var() except that it stores multiple I<VALUE>s.
The main difference is that in order to delete the I<KEY> you must pass a single undef to the accessor as a parameter.

_varArray() stores the given values in an array reference but will always return the values
as a dereferenced array so you never have to worry about dereferencing it yourself.

B<Warning>: don't mix using _var() and _varArray() for the same key or try to set the key manually.
You can easily get a nasty error message.
To see the message, do this:

  # --- accessor in the class ---
  sub names { shift->_varArray(allNames => @_) }

  # --- your messed-up code ---
  $obj->{allNames} = 'Jim';
  my @list = $obj->names;   # ... stack trace of death

=item $obj->B<_varDefault>(I<DEFAULT>, I<KEY> [=> I<VALUE>])

This method is a wrapper for _var() that returns I<DEFAULT> where _var() would otherwise return undef.

If you have a code block (via C<sub { ... }>) as I<DEFAULT>, the return value for the block will be returned.
Note that the code block is executed every time the default value is rendered.
This can have a significant performance impact but also allows you to change the default value any time the accessor is used.

=item $obj->B<CLASS>()

Returns the object's class name.
Equivelant to B<ref>($obj).

=back

=head1 TODO, KNOWN ISSUES AND BUGS

=over 2

=item ToDo: B<Implement Accessor Auto-creation a la Class::Accessor(3pm)>

=back

=head1 REPORTING BUGS

Report bugs in the iTools' issue tracker at
L<https://github.com/iellenberger/itools/issues>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2012 by Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<https://github.com/iellenberger/itools/blob/master/LICENSE>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 DEPENDENCIES

strict(3pm) and warnings(3pm)

=head1 SEE ALSO

=cut
