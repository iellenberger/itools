package HashRef::Flat;
use base qw( Exporter );
$VERSION = "0.0.1";

@EXPORT_OK = qw( flatten flathash );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=$Data::Dumper::Terse=1; # for debugging only
use List::Util qw( max );
use Scalar::Util qw( blessed );
use Storable qw( dclone );

#use Time::HiRes qw( usleep );

use strict;
use warnings;

# === Class Variables =======================================================
# --- obscure key for internal config ---
our $cfgkey = __PACKAGE__ . join("\b", split('', "#^&(){}-=_+[];:<>,./?!"));

our $_isflattening = 0;

# === Constructor and Export Wrapper ========================================

# --- constructor ---
sub new {
	my $this = shift;
	my $class = ref($this) || $this;

	# --- if odd number of params, first is source hash ---
	my $inhash = @_ % 2 ? shift : {};

	# --- create a hash-tied object ---
	my %hash; tie %hash, $class;      # tie hash to class (for hash tie)
	my $self = bless \%hash, $class;  # bless ref to tied hash into class (for object)

	# --- parse incoming parameters ---
	my %args = @_;
	while (my ($key, $value) = each %args) {
		$key =~ /^hashd/i  && $self->hashdelim($value);
		$key =~ /^arrayd/i && $self->arraydelim($value);
	}

	# --- merge source hash and return self ---
	return $self->flatten($inhash);
}

# === Accessors =======================================================================
sub hashdelim    { shift->_varDefault('.', hashdelim  => @_) }
sub arraydelim   { shift->_varDefault(':', arraydelim => @_) }

# --- internal accessors ---
sub _isflat       { shift->_var(_isflat     => @_) }
sub _isflattening { shift; @_ ? $_isflattening = shift || 0 : $_isflattening || 0 }

# --- universal accessor from iTools::Core::Accessor ---
sub _var {
	my ($self, $key) = (shift, shift);

	# --- get the vars hash to aviod innecessary calls to self ---
	my $vars = $self->{$cfgkey} ||= {};

	# --- get the value ---
	unless (@_) {
		return $vars->{$key} if exists $vars->{$key};
		return undef;
	}

	# --- delete the key if value = undef ---
	unless (defined $_[0]) {
		my $value = $vars->{$key};  # store the old value
		delete $vars->{$key};       # delete the key
		return $value;              # return the old value
	}

	# --- set and return the value ---
	return $vars->{$key} = shift;
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

	# --- return the default value ---
	return $default;
}



# === Hash Flattening and Configuration Interpolation =======================

#sub flat { __PACKAGE__->new->flatten(@_) }

# --- alias for flatten ---
sub merge { shift->flatten(@_) }

sub flatten {
	my $self = 
		$_[0] && UNIVERSAL::isa($_[0], __PACKAGE__) ? shift : __PACKAGE__->new;

	# --- test for conditions where we can skip processing ---
	return $self if $self->_isflattening;       # we're currently flattening
	return $self if $self->_isflat && @_ == 0;  # we're flat and there are no args

	# --- mark that we're currently flattening ---
	$self->_isflattening(1);

	# --- merge arguments into a single hash ---
	if (@_) {
		my $inhash = {};
		while (my $arg = shift) {

			# --- if arg is hashref, walk it into self ---
			if (UNIVERSAL::isa($arg, 'HASH')) {
				my @keys = keys %$arg;
				@{$inhash}{@keys} = @{$arg}{@keys};
				next;
			}
		
			# --- if arg is scalar, presume it a touple ---
			if (not ref $arg) {
				$inhash->{$arg} = shift;
				next;
			}

			# --- do a WTF if the arg is the wrong type ---
			#! TODO: make this message meaningful
			print "WTF? $arg\n";
			exit 1;
		}

		$inhash = flathash($inhash);

		my @keys = keys %$inhash;
		@{$self}{@keys} = @{$inhash}{@keys};

	}

	my @keys = sort keys %$self;

	foreach my $key (@keys) {
		next if $key eq $cfgkey;
		my $value = $self->{$key};

		if (UNIVERSAL::isa($value, 'HASH') && ! %$value) {
			$self->{$key} = {};
		} elsif (UNIVERSAL::isa($value, 'ARRAY') && ! @$value) {
			$self->{$key} = [];
		} else {
			my $subhash = flathash($self->{$key}, $key);
			delete $self->{$key};
			my @subkeys = keys %$subhash;
			map { $self->{$_} = $subhash->{$_} } keys %$subhash;
		}
	}

	# --- mark that we're flat and are done flattening ---
	$self->_isflat(1);
	$self->_isflattening(0);

	return $self;
}


sub flathash {
	my ($ds, $prefix) = @_;
	my $flat = {};
	return $flat unless defined $ds;

	if (ref $ds eq 'HASH') {
		foreach my $key (keys %$ds) {
			my $subhash = flathash($ds->{$key}, defined $prefix ? "$prefix.$key" : $key);
			map { $flat->{$_} = $subhash->{$_} } keys %$subhash;
		}
	} elsif (ref $ds eq 'ARRAY') {
		for (my $key = 0; $key < @$ds; $key++) {
			my $subhash = flathash($ds->[$key], defined $prefix ? "$prefix:$key" : $key);
			map { $flat->{$_} = $subhash->{$_} } keys %$subhash;
		}
	} else {
		$flat = { $prefix => $ds };
	}

	return $flat;
}

# === Utility Methods =======================================================
# --- return the untied hash ---
sub untied {
	exists $_[0]->{"_untied $cfgkey"}
		? $_[0]->{"_untied $cfgkey"}
		: $_[0];
}

# --- interpolate self into a block of text ---
sub interpolate {
	my ($self, $text) = @_;
	while (my ($key, $value) = each %$self) {
		$text =~ s/\${$key}/$value/g;
	}
	return $text;
}

sub unflatten {
	my $self = shift;

	my $hd = $self->hashdelim;
	my $ad = $self->arraydelim;

	my $expanded = {};

	my $delimre = '((?:' . quotemeta($hd) . ')|(?:' . quotemeta($ad) . '))';
	$delimre = '(?<!\\\\)'. $delimre; #Use negative look behind

	foreach my $key (reverse sort keys %$self) {
		my $value = $self->{$key};

		my @parts = split /$delimre/, $key;
		#print Dumper([@parts, $value]);

		my $lastkey = pop @parts;

		my $ptr = $expanded;
		while (@parts >= 2) {
			my ($subkey, $type) = (shift @parts, shift @parts);

			if ($type eq $hd) {
				if (UNIVERSAL::isa($ptr, 'HASH')) {
					$ptr->{$subkey} = {} unless exists $ptr->{$subkey};
					$ptr = $ptr->{$subkey};
				} else {
					$ptr->[$subkey] = {} unless defined $ptr->[$subkey];
					$ptr = $ptr->[$subkey];
				}
			} elsif ($type eq $ad) {
				if (UNIVERSAL::isa($ptr, 'HASH')) {
					$ptr->{$subkey} = [] unless exists $ptr->{$subkey};
					$ptr = $ptr->{$subkey};
				} else {
					$ptr->[$subkey] = [] unless defined $ptr->[$subkey];
					$ptr = $ptr->[$subkey];
				}
			} else {
				die "Type '$type' was not recognized. This should not happen.";
			}
		}

		if (UNIVERSAL::isa($ptr, 'HASH')) {
		if (exists $ptr->{$lastkey}) { print "Whaaaa?????!!!!\n"; }
			$ptr->{$lastkey} = $value;
		} else {
		if (exists $ptr->[$lastkey]) { print "Whaaaa?????!!!!\n"; }
			$ptr->[$lastkey] = $value;
		}
	}

	return $expanded;
}


# === Hash Tie Stuff ========================================================
# --- stock hashtie methods ---
sub TIEHASH  { bless $_[1] || {}, ref($_[0]) || $_[0] }
sub CLEAR    { delete @{$_[0]}{keys %{$_[0]}} }
sub DELETE {
	my ($self, $key) = (shift->flatten, shift);
	delete $self->{$key};
}

# --- process cfgkey keys specially ---
sub EXISTS {
	my ($self, $key) = (shift, shift);
	return 1 if $key =~ /$cfgkey$/;  # filter internal configuration

	# --- force flatten if the key does not exist ---
	$self->_isflat(0) unless exists $self->{$key};
	$self->flatten;

	return exists $self->{$key};
}

sub FETCH {
	my ($self, $key) = (shift, shift);
	return $self if $key eq "_untied $cfgkey";   # return untied hash
	return $self->{$cfgkey} if $key eq $cfgkey;  # filter internal config

	# --- force flatten if the key does not exist ---
	$self->_isflat(0) unless exists $self->{$key};
	$self->flatten;

	return $self->{$key};
}

# --- filter out hidden values for keys() or each() ---
sub FIRSTKEY {
	my $self = shift->flatten;

	# --- reset to first key ---
	scalar keys %{$self};

	# --- return next exposed key ---
	while (my ($key, $value) = each %{$self}) {
		return (wantarray ? ($key, $value) : $key)
			unless $key eq $cfgkey;  # filter internal config
	}

	return undef;
}
sub NEXTKEY  {
	# --- return next exposed key ---
	while (my ($key, $value) = each %{$_[0]}) {
		return (wantarray ? ($key, $value) : $key)
			unless $key eq $cfgkey;  # filter internal config
	}
	return undef;
}

sub STORE {
	my ($self, $key, $value) = @_;

	# --- mark the object as not flat if we're storing a hash or array ref ---
	$self->_isflat(0)
		if ref $value and $key ne $cfgkey and
			(UNIVERSAL::isa($value, 'HASH') or UNIVERSAL::isa($value, 'ARRAY'));

	# --- set the value and return ---
	return $self->{$key} = $value;
}


=head1 NAME

HashRef::Flat - converts hash to a flattened datastructure

=head1 SYNOPSIS

Functional Interface:

  use HashRef::Flat qw( flatten flathash )

  my $flatobj  = flatten($myhash);   # returns object
  my $flathash = flathash($myhash);  # returns hash

OO Interface:

  use HashRef::Flat;

  # --- create object ---
  my $obj = new HashRef::Flat($myhash);

  # --- add data ---
  $obj->{a}{b} = 'foo';     # new key: 'a.b'
  $obj->{c}[0] = 'bar';     # new key: 'c:0
  $obj->{d}[1]{e} = 'boo';  # new key: 'd:1.e'

  # --- merge another hash on top of the current one ---
  $obj->merge($myotherhash};

  # --- convert back to datastructure ---
  my $hash = $obj->unflatten;

  # --- variable interpolation ---
  my $newtext = $obj->interpolate($text);

=head1 DESCRIPTION

B<HashRef::Flat> is a class which auto-flattens data structures into simple
key-value pairs.

=head2 Example:

Code:

  # --- your data structure ---
  $nested = {
    'x' => 1,
    'y' => { 'a' => 2, 'b' => 3 },
    'z' => [ 'a', 'b', 'c' ],
  }

  # --- flatten to a hash ---
  print '$hash = '. Dumper(flathash($nested));
  # --- flatten to an object ----
  print '$obj = '. Dumper(flatten($nested));

Output:

  $hash = {
     'x' => 1,
     'y.a' => 2,
     'y.b' => 3,
     'z:0' => 'a',
     'z:1' => 'b',
     'z:2' => 'c'
  };
  $obj = bless( {
     ... same as above ...
  }, 'HashRef::Flat' )

More code:

  # --- expand back to nested datastructure ---
  my $nested2 = $obj->unflatten;

When using the OO interface, additional L</OPTIONS> are available to change
the object's behaviour.

=head1 FUNCTIONAL INTERFACE

=over 2

=item B<flathash>(I<HASH>)

This returns an unblessed flattened version of I<HASH>.
OO functions are not available for the returned hash.

=item B<flatten>(I<HASH> [,...])

This returns a blessed hash (i.e. object) containing the merged I<HASH>es
given as paramters.

Without paramteters, it acts as a simple constructor.

=item B<unflatten>(I<HASH>)

=item B<interpolate>(I<HASH>)

Not yet implemented.
See L</TODO>.

=back

=head1 OO INTERFACE

Using B<HashRef::Flat> as an object gives additional functionality including
the ability to add values to the flattened hash on the fly.

This example shows how adding values to the object converts incoming
datastructures into their respecitve flattened key/value pairs:

  my $obj = new HashRef::Flat();

  $obj->{k1} = 'v1';                # scalar
  $obj->{k2}->{1} = 'v2.1';         # hash, indirect
  $obj->{k3} = { 1 => 'v3.1' };     # hash, direct
  $obj->{k4}->[0] = 'v4:0';         # array, direct
  $obj->{k5} = [ 'v5:0', 'v5:1' ];  # array, indirect

  print '$obj = '. Dumper($obj);

Output:

  $obj = bless( {
    'k1' => 'v1',
    'k2.1' => 'v2.1',
    'k3.1' => 'v3.1',
    'k4:0' => 'v4:0',
    'k5:0' => 'v5:0',
    'k5:1' => 'v5:1'
  }, 'HashRef::Flat' )

=head2 Constructor

=over 2

=item new B<HashRef::Flat>([I<HASH>,] [OPTIONS])

Creates a new B<HashRef::Flat> object.
You can pass an existing I<HASH> to seed the object.

Valid I<OPTIONS> are 'HashDelim => I<DELIMETER>' and 'ArrayDelim => I<DELIMETER>'.
See L</Accessors> for details on these parameters.

=back

=head2 Accessors

=over 2

=item $obj->B<hashdelim>([I<DELIMETER>])

=item $obj->B<arraydelim>([I<DELIMETER>])

These accessors allow you to get/set the I<DELIMETER>s used for flattening
hashes and arrays.

Called without parameters, they return the current I<DELIMETER>.
With a parameter, they set the value to be used as the I<DELIMETER>.
If you use C<undef> as the parameter, they reset the delimeter to the default value.
You may use multi-character strings as I<DELIMETER>s.

Delimeters should be set before seeding values into the hash.
See L</CAVEATS> for more details.

Both accessors return the value of the current delimiter.
Default delimeters are '.' for hashes and ':' for arrays.

=back

=head2 Methods

=over 2

=item $obj->B<flatten>([I<HASH> [,...]])

=item $obj->B<merge>([I<HASH> [,...]])

These methods merge the given hashes into the object and then flatten the
contents of the object ofter the fact.

Merging is useful for when you have, for example, multiple configuration
files where you want each successive file's values to clobber the values of
the previous file.
In this case, you would load each file into a datastructure and then merge
its contents into the object.

Example pseudocode:

  my $cfg1 = readfile('config1');  # master appplication config
  my $cfg2 = readfile('config2');  # host-specific config
  my $cfg3 = readfile('config3');  # environment-specific config

  my $obj = new HashRef::Flat($cfg1);
  $obj->merge($cfg2, $cfg3);

or alternately for tha last few lines:

  my $obj = flatten($cfg1, $cfg2, $cfg3);

If called without parameters, only the flatten operation will be performed.
If called in a functional form, a new object will be created.

Returns the existing or created object.

=item $obj->B<unflatten>

=item $obj->B<interpolate>(I<TEXT>)

Allows you to interpolate the contents of the object into a given block of text.

Although this functionality is somewhat out-of-scope of the core
functionality of this package, I decided to include it 'cause it's
super-useful, and only 7 lines of code.

Lets say you have a config file like so (using YAML in this example):

  name : Ingmar Ellenberger
  home :
    address :
      - 2020 Home Ave.
      - Suite 300
    zip : 98039
    city : Medina
    state : WA

and a template that looks like this:

  If you find this person walking around aimlessly, please return them to:

    ${name}
    ${home.address:0} ${home.address:1}
    ${home.city}, ${home.state} ${home.zip}

you can write (pseudo)code that looks like this:

  my $info = flatten readYAML('myaddress.yaml');
  my $template = readfile 'lostperson.txt';
  print $info->interpolate($template);

(You can figure out the output yourself)

The format is simple: the flattened key inside of a dollar-curley bracket.
Any keys that are not in the object/hash remain unrendered.

=item $obj->B<untied>

Returns the untied, unblessed object.

This is mostly useful for development and debugging.
It exposes the hidden keys used for configutaion of the object.

=back

=head1 NOTES

scalar refs and code

return value undef when adding non-scalar

setting delimieters after seeding vcalues

conflicting keys in unflatten

Storing empty hashes and arrays

clobber on merge

dots in keys

caveats: intense processing - concern for large datasets

threadsafe

escaping templated variables

=head1 CAVEATS

=over 2

=item

=back

=head1 TODO

Most of this stuff is things I simply havn't gotten around to doing.

=over 2

=item B<Provide a functional interface for unflatten()>

=item B<Provide a functional interface for interpolate()>

=item B<Detect recursive structures>

=back

=head1 KNOWN ISSUES AND BUGS

See L</CAVEATS> and L</TODO>.

=head1 SEE ALSO

The perlmonks site has a helpful introduction to when and why you might want
to flatten a hash: L<http://www.perlmonks.org/index.pl?node_id=234186>



=head1 REPORTING BUGS

Report bugs in the iTools' issue tracker at
L<https://github.com/iellenberger/itools/issues>

=head1 AUTHOR

Ingmar Ellenberger

Code fragments and documentation snippets taken from B<Hash::Flatten>,
authored by John Alden & P Kent.

=head1 COPYRIGHT

Copyright (c) 2001-2014 by Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<https://github.com/iellenberger/itools/blob/master/LICENSE>
or read the F<LICENSE> in the root of the iTools distribution.

Inspired by, and some code fragments taken from B<Hash::Flatten>,
Copyright (c) BBC 2005, distributed under the GNU GPL.

=head1 DEPENDENCIES

Exporter(3pm)

=head1 SEE ALSO

perldata(1),

=cut

1;
