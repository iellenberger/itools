package HashRef::Maskable;
use base qw( Exporter );
$VERSION = "0.01";
@EXPORT_OK = qw( mhash );

use strict;
use warnings;

# === Class Variables =======================================================
# --- obscure string for hiding class' own settings ---
our $obscure = __PACKAGE__ . join("\b", split('', "#^&(){}-=_+[];:<>,./?!")) ."\b";

# === Constructor and Export Wrapper ========================================
# --- constructor alias for OO use ---
sub new { shift; mhash(@_) }

# --- exported sub and real constructor ---
sub mhash {
	# --- if odd number of params, presume first is classname --
	my $this = @_ % 2 ? shift : __PACKAGE__;
	my $class = ref($this) || $this;

	# --- create a hash-tied object ---
	my %hash; tie %hash, $class;      # tie hash to class (for hash tie)
	my $self = bless \%hash, $class;  # bless ref to tied hash into class (for object)

	# --- seed the hash ---
	my %seeds = @_;
	map { $self->{$_} = $seeds{$_} } keys %seeds;

	return $self;
}

# === Hooks =================================================================
sub _fetch  { $_[0]->{$_[1]} }
sub _store  { $_[0]->{$_[1]} = $_[2] }
sub _exists { exists $_[0]->{$_[1]} }
sub _delete { delete $_[0]->{$_[1]} }

# === Utility Methods =======================================================
# --- return the untied hash ---
sub untied {
	exists $_[0]->{"_untied $obscure"}
		? $_[0]->{"_untied $obscure"}
		: $_[0];
}

# === Hash Tie Stuff ========================================================
# --- stock hashtie methods ---
sub TIEHASH  { bless $_[1] || {}, ref($_[0]) || $_[0] }
sub CLEAR    { delete @{$_[0]}{keys %{$_[0]}} }
sub STORE    { $_[0]->_store($_[1] => $_[2]) }
sub DELETE   { $_[0]->_delete($_[1]) }

# --- process obscure keys specially ---
sub EXISTS   { $_[1] eq "_untied $obscure" ? 1     : $_[0]->_exists($_[1]) }
sub FETCH    { $_[1] eq "_untied $obscure" ? $_[0] : $_[0]->_fetch($_[1]) }

# --- filter out hidden values for keys() or each() ---
sub FIRSTKEY {
	# --- reset to first key ---
	scalar keys %{$_[0]};

	# --- return next exposed key ---
	while (my ($key, $value) = each %{$_[0]}) {
		return (wantarray ? ($key, $value) : $key)
			unless $key =~ /^_/;
	}

	return undef;
}

sub NEXTKEY  {
	# --- return next exposed key ---
	while (my ($key, $value) = each %{$_[0]}) {
		return (wantarray ? ($key, $value) : $key)
			unless $key =~ /^_/;
	}

	return undef;
}

1;

=head1 NAME

HashRef::Maskable - hashref with hidden (private) keys

=head1 SYNOPSIS

Using:

   use HashRef::Maskable;

   my $hash = mhash();
   $hash->{username}  = 'joedoe';  # exposed
   $hash->{_password} = 'doejoe';  # hidden

Extending:

   package MyClass;
   use base 'HashRef::Maskable';

   sub new { shift->mhash(@_) }

   sub _fetch  { print "FETCH called\n"  }
   sub _store  { print "STORE called\n"  }
   sub _exists { print "EXISTS called\n" }
   sub _delete { print "DELETE called"\n }

=head1 DESCRIPTION

B<HashRef::Maskable> is a class which 'hides' any key within a hash.
It does this by convincing the hash iterators (B<each>(), B<keys>(), B<values>()) to only return values that do not start with an underscore '_'.
By doing so, you can hide keys within a hash by prefixing them with an underscore.

=head2 Basic Usage

Using B<HashRef::Maskable> is quite simple - create the hash and add values to it.
If you don't want a key to show up while iterating through the hash, prepend in underscore to it.

   my ($hash, @keys, $foo);       # strict!

   $hash = mhash();               # create hash/obj
   $hash->{user}  = 'sasquatch';  # add a visable pair
   $hash->{_pass} = 'Br0wnY3t1';  # add a hidden pair

   @keys = keys %$hash;           # @('user')
   @keys = keys %{$hash->untied}; # @('user', '_pass')

   $foo = $hash->{user};          # 'sasquatch';
   $foo = $hash->{_pass};         # 'Br0wnY3t1';

When using iterators (B<keys>, B<values>, B<each>), only the exposed values appear unless you use B<untied>(),
but if you use the right key, all values are still available.

Note that you can also seed the hash through the constructor:

   $hash = mhash(
      user  => 'sasquatch',
      _pass => 'Br0wnY3t1',
   );

=head2 Extending the Package

Here's an example of how to extend B<HashRef::Maskable>.
The following class will convert values to upper or lower case depending on parameters passed to to constructor.

   package ChangeCase;
   use base 'HashRef::Maskable';

   sub new {
      my ($class, $case, %hash) = @_;
      my $self = $class->mhash(%hash);

      # --- set the case we want to convert to ---
      $self->{_case} = $case;

      return $self;
   }

   sub _fetch {
      my ($self, $key) = (shift->untied, shift);

      # --- don't convert hidden values ---
      return $self->{$key} if $key =~ /^_/;

      # --- convert to upper or lower case ---
      return uc $self->{$key} if $self->{_case} eq 'upper';
      return lc $self->{$key} if $self->{_case} eq 'lower';

      # --- otherwise leave it alone ---
      return $self->{$key};
   }

(descriptions as follows ...)

=over 3

=item The Constructor:

In the constructor, we don't need to B<bless> the object into C<$class> because the parent's class method B<mhash>() will do it for us.
If you REALLY want to go through the process of blessing it yourself, you can always write:

   my $self = bless $class->mhash(%hash), $class;

or even worse:

   use HashRef::Maskable 'mhash';
   my $self = bless mhash(%hash), $class;

but this (minimally) increases overhead and provides no benefit.

=item Overriding B<_fetch>():

B<_fetch>() defines C<$self> as B<shift>->B<untied>() to ensure we have the non-hashtied version of the object.
This is done because we want direct access to all data without the restrictions placed on it by the hash tie.
See the description for the B<untied>() method below for an explanation of when and why you should use it.

The rest of the code is self-evident.

=item Overriding Other Methods:

If you can think of reasons to override the remaining hooks, the interface is there for you to do it.
Here are some examples of entirely useless extensions:

   # --- save all values as Piglatin ---
   sub _store {
      my $self  = shift->untied;
      my $key   = shift;
      my $value = Pig::Latin::convert($value);

      return $self->{$key} = $value;
   }

   # --- an easter egg! ---
   sub _exists {
      my ($self, $key) = (shift->untied, shift);
      print "Easter Egg!\n" if $key eq 'BunnyRabbit';
      return exists $self->{$key};
   }

   # --- confirm everything, just like Vista ---
   sub _delete {
      my ($self, $key) = (shift->untied, shift);

      return delete $self->{$key}
         if Annoying::Popup("Are you sure?") eq 'yes';

      return undef;
   }

=back

=head1 METHODS AND EXPORTS

=over 3

=item B<Constructors>

=over 3

=item B<new> HashRef::Maskable([I<HASH>])

The B<new> method is simply an alias for the B<mhash>() export.
See the documentation below for details.

=item B<mhash>([I<HASH>])

This is the actual constructor for B<HashRef::Maskable>.
It recognizes the when it is called as a method as opposed to a function based on the number of parameters passed:
if there is an odd number parameters, the first argument is shifted off the stack and used as the class name.

You can pass a number of key/value pairs (i.e. I<HASH>) as parameters and they will be used as seed values for the hash.

Returns a blessed object.

=back

=item B<Utility Methods>

=over 3

=item B<untied>()

B<untied>() allows you direct access to the hash's members without being filtered through the hash-tied methods
(B<FIRSTKEY>(), B<NEXTKEY>(), B<STORE>(), B<FETCH>(), ...) and object hooks (B<_fetch>(), B<_store>(), ...).

B<untied>() returns an un-hash-tied version of the object, even if the object is already untied.

This type of direct access has several particularly useful applications:

=over 3

=item Viewing Private Keys:

By avoiding the B<FIRSTKEY>() and B<NEXTKEY>() methods, you can view all keys through B<untied>():

   keys %$obj            # exposed keys only
   keys %{$obj->untied}  # all keys, hidden and exposed
   keys %{untied $obj}   # same thing, different syntax

This also works for C<each()> and C<values()>.

=item Preventing Infinite Recursion:

When modifying the behavior of B<HashRef::Maskable> in a subclass, you run the risk of infinite recursion
if you're not careful.
If you create the following class:

   package Upper;
   use base 'HashRef::Maskable';

   sub _fetch { $_[0]->upper($_[1]) }
   sub upper  { uc $_[0]->{$_[1]} }

And the use it like this:

   use Upper;
   my $hash = new Upper(name => 'harry');

   $foo = $hash->{name};         # 'HARRY'
   $foo = $hash->upper('name');  # recursion error

You would have a big problem.
In the first C<print> statement, the C<upper()> method would have recieved an B<untied>() object and everything would work fine.
For the second C<print> statement, it would have recieved the tied object, thereby creating an infinite recursion loop.

The solution is to guarantee that C<upper()> always has an B<untied>() object like this:

   sub upper  { uc $_[0]->untied->{$_[1]} }

=item Viewing Unmodified Values:

If you are using this in a subclass that modifies hash values through the B<_fetch>() hook (ex. variable interpolation, case conversion, etc.),
B<untied> will allow you to see the original value:

   $value = $obj->{'key'};          # called via _fetch()
   $value = $obj->untied->{'key'};  # _fetch() not called

=back

=back

=item B<Hooks>

=over 3

=item B<_fetch>(I<KEY>)

=item B<_store>(I<KEY>, I<VALUE>)

=item B<_delete>(I<KEY>)

=item B<_exists>(I<KEY>)

These methods are overridable hooks called from standard hash-tied methods.
They are implemented (almost) literally as follows:

   # --- hash tie ---
   sub STORE   { $_[0]->_store($_[1] => $_[2]) }
   sub DELETE  { $_[0]->_delete($_[1]) }
   sub EXISTS  { $_[0]->_exists($_[1]) }
   sub FETCH   { $_[0]->_fetch($_[1]) }

   # --- hooks called by hash tie ---
   sub _fetch  { $_[0]->{$_[1]} }
   sub _store  { $_[0]->{$_[1]} = $_[2] }
   sub _exists { exists $_[0]->{$_[1]} }
   sub _delete { delete $_[0]->{$_[1]} }

When called from the hash-tied methods, the first parameter (C<$self>) will ALWAYS be the B<untied>() hash object.
If you call these methods directly, there is no guarantee that this is true.
If you are uncertain how the method was called and whether $self is tied or untied, you can guarantee that you have the B<untied>() hash with this code:

   sub fetch {
      my $self = shift->untied;
      ...
   }

IMPORTANT NOTE FOR ADVANCED USERS:

Do not overload the hash-tied methods B<EXISTS>() and B<FETCH>() without properly calling the parent methods (look at the code to understand what 'properly' means).
Doing so will break the B<untied>() method.

=back

=back

=head1 DEVELOPMENT NOTES

In selecting a name for this class, I was concerned that the name/term '[Pp]rivate' would create a mental clash with the OO concept of a 'private member'.
To resolve this, I named early prototypes of this package B<Hash::Hidden> but found that the name was equally ambigious (for other reasons) and much less memorable.
In the end, I stuck with B<HashRef::Maskable>, but if you have a suggestion for a better name, let me know (see L</AUTHOR>).

=head1 TODO

=over 3

=item B<Add Remapping Function>

A remapping function may not seem to be appropriate for this class, but it can be useful in hiding values that do not start with an underscore.
For example:

   remap('password' => '_password');

would allow a user to store a password without having it show up when dumpong the hash.

A question on implementation: Do we remap existing values?
I would presume, "yes," but have not examined all possibilities.

=back

=head1 KNOWN ISSUES AND BUGS

None.

=head1 REPORTING BUGS

Report bugs in the Bug Tracker at iTools' SourceForge project page:
L<http://sourceforge.net/projects/itools/>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2012 by Ingmar Ellenberger.

Distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 DEPENDENCIES

Exporter(3pm)

=head1 SEE ALSO

perldata(1),
perltie(1)

=cut
