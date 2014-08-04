package HashRef::Flat;
use base qw( Exporter );
$VERSION = "1.0.0";

@EXPORT_OK = qw( mkflat flatten unflatten interpolate );

#use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=$Data::Dumper::Terse=1; # for debugging only
use Scalar::Util qw( blessed );

use strict;
use warnings;

# === Class Variables =======================================================
# --- obscure key for internal config ---
our $_cfgkey = __PACKAGE__ . join("\b", split('', "#^&(){}-=_+[];:<>,./?!"));
# --- used to track whether we're in the process of merging ---
our $_ismerging = 0;

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
		$key =~ /^a/i || $key eq 'ad' && $self->arraydelim($value);
		$key =~ /^h/i || $key eq 'hd' && $self->hashdelim($value);
	}

	# --- merge source hash and return self ---
	return $self->merge($inhash);
}

# --- alternate constructor ---
sub mkflat { __PACKAGE__->new->merge(@_) }

# === Accessors =======================================================================
sub ad {
	my $self = shift;
	$self->_selfflatten if @_;
	$self->_varDefault(':', arraydelim => @_);
}
sub hd {
	my $self = shift;
	$self->_selfflatten if @_;
	$self->_varDefault('.', hashdelim  => @_);
}
sub arraydelim { shift->ad(@_) }
sub hashdelim  { shift->hd(@_) }
sub adhd {
	my ($self, $ad, $hd) = @_;
	$ad = defined $ad ? $self->arraydelim($ad) : $self->arraydelim;
	$hd = defined $hd ? $self->hashdelim($hd)  : $self->hashdelim;
	return ($ad, $hd);
}

# --- internal accessors ---
sub _isflat    { shift->_var(_isflat => @_) }
sub _ismerging { shift; @_ ? $_ismerging = shift || 0 : $_ismerging || 0 }

# === Hash Flattening and Configuration Interpolation =======================

# --- merge new data into the object and flatten the object ---
sub merge {
	my $self = shift;

	# --- merge incoming data into self ---
	my @adhd = $self->adhd;
	if (@_) {

		# --- create a new hash for incoming data ---
		my $inhash = {};

		# --- iterate through arguments and merge into $inhash ---
		while (my $arg = shift) {
			# next unless defined $arg;

			# --- if arg is hashref, walk it into self ---
			if (_isa($arg, 'HASH')) {
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

		# --- flatten the incoming hash ---
		$inhash = flatten($inhash, undef, @adhd);

		# --- merge incoming hash into self ---
		my @keys = keys %$inhash;
		@{$self}{@keys} = @{$inhash}{@keys};
	}

	$self->_selfflatten;

	return $self;
}

sub _selfflatten {
	my ($self, $force) = @_;

	unless ($force) {
		# --- test for conditions where we can skip processing ---
		return $self if $self->_ismerging;          # we're currently flattening
		return $self if $self->_isflat           ;  # we're flat and there are no args
	}
	
	# --- mark that we're currently flattening ---
	$self->_ismerging(1);

	# --- check values in self and flatten non-scalars ---
	my @adhd = $self->adhd;
	my $notflat = 0;
	foreach my $key (sort keys %$self) {
		next if $key eq $_cfgkey;  # ignore internal configuration

		my $value = $self->{$key};

		# --- a bit of trickery needed for Perl's evaluation order ---

		# We are required to return empty hash/array refs for code that looks
		# like this:
		#
		#    $obj->{key}{key} = value; or
		#    $obj->{key}[0]   = value;
		#
		# See CAVEATS in the manpage for more info

		if (_isa($value, 'HASH') && ! %$value) {
			$self->{$key} = {};
			$notflat = 1;
		} elsif (_isa($value, 'ARRAY') && ! @$value) {
			$self->{$key} = [];
			$notflat = 1;
		} elsif (_isa($value, 'HASH', 'ARRAY')) {
			# --- flatten all non-scalars ---
			my $subhash = flatten($self->{$key}, $key, @adhd);
			delete $self->{$key};
			my @subkeys = keys %$subhash;
			map { $self->{$_} = $subhash->{$_} } keys %$subhash;
		}
	}

	# --- mark that we're flat and are done flattening ---
	$self->_isflat(1) unless $notflat;
	$self->_ismerging(0);

	return $self;
}

# === Functional (i.e. non-OO) Code =========================================

# --- flatten a hash (or array) ---
sub flatten {
	my ($ds, $prefix, $ad, $hd) = @_;

	# --- set defaults for delimiters ---
	$ad = ':' unless defined $ad;
	$hd = '.' unless defined $hd;

	my $flat = {};
	return $flat unless defined $ds;

	if (ref $ds eq 'HASH') {
		foreach my $key (keys %$ds) {
			my $subhash = flatten($ds->{$key}, defined $prefix ? "$prefix$hd$key" : $key, $ad, $hd);
			map { $flat->{$_} = $subhash->{$_} } keys %$subhash;
		}
	} elsif (ref $ds eq 'ARRAY') {
		for (my $key = 0; $key < @$ds; $key++) {
			my $subhash = flatten($ds->[$key], defined $prefix ? "$prefix$ad$key" : $key, $ad, $hd);
			map { $flat->{$_} = $subhash->{$_} } keys %$subhash;
		}
	} else {
		$flat = { $prefix => $ds };
	}

	return $flat;
}

# --- unflatten a hash ---
sub unflatten {
	my $hash = shift;

	# --- get the delimiters ---
	my ($hd, $ad) = ('.', ':');
	if (_isa($hash, __PACKAGE__)) {
		$hd = $hash->hashdelim;
		$ad = $hash->arraydelim;
	}

	# --- this is where we store the expanded datastructure ---
	my $expanded = {};

	# --- build the regex for splitting the keys ---
	my $delimre = '((?:' . quotemeta($hd) . ')|(?:' . quotemeta($ad) . '))';
	$delimre = '(?<!\\\\)'. $delimre; #Use negative look behind

	# --- walk through all keys ---
	foreach my $key (reverse sort keys %$hash) {
		my $value = $hash->{$key};

		# --- split key into parts ---
		my @parts = split /$delimre/, $key;
		my $lastkey = pop @parts;

		# --- walk through part touples and build the links ---
		my $ptr = $expanded;  # the current link
		while (@parts >= 2) {
			my ($subkey, $type) = (shift @parts, shift @parts);

			# --- add a hash ---
			if ($type eq $hd) {
				if (_isa($ptr, 'HASH')) {
					$ptr->{$subkey} = {} unless exists $ptr->{$subkey};
					$ptr = $ptr->{$subkey};
				} else {
					$ptr->[$subkey] = {} unless defined $ptr->[$subkey];
					$ptr = $ptr->[$subkey];
				}
			}

			# --- add an array ---
			elsif ($type eq $ad) {
				if (_isa($ptr, 'HASH')) {
					$ptr->{$subkey} = [] unless exists $ptr->{$subkey};
					$ptr = $ptr->{$subkey};
				} else {
					$ptr->[$subkey] = [] unless defined $ptr->[$subkey];
					$ptr = $ptr->[$subkey];
				}
			}
			
			# --- something went wrong ---
			else {
				die "Type '$type' was not recognized. This should not happen.";
			}
		}

		# --- add $lastkey ---
		if (_isa($ptr, 'HASH')) {
			print "warning: conflict while trying to unflatten '$key'\n"
				if exists $ptr->{$lastkey};
			$ptr->{$lastkey} = $value;
		} else {
			print "warning: conflict while trying to unflatten '$key'\n"
				if exists $ptr->[$lastkey];
			$ptr->[$lastkey] = $value;
		}
	}

	return $expanded;
}

# --- interpolate hash into a block of text ---
sub interpolate {
	my ($hash, $text) = @_;
	while (my ($key, $value) = each %$hash) {
		$text =~ s/\${$key}/$value/g;
	}
	return $text;
}

# === Utility Methods =======================================================
# --- return the untied hash ---
sub untied {
	exists $_[0]->{"_untied $_cfgkey"}
		? $_[0]->{"_untied $_cfgkey"}
		: $_[0];
}

# --- internal implementation of UNIVERSAL::isa() ---
sub _isa {
	my ($obj, @types) = @_;

	# --- walk through types or'ing each ---
	my $found = 0;
	foreach my $type (@types) {
		$found++ if blessed $obj && $obj->isa($type);
		$found++ if ref $obj eq $type;
	}

	return $found ? 1 : 0;
}

# === Bits stripped from iTools::Core::Accessor =============================

# --- universal accessor ---
sub _var {
	my ($self, $key) = (shift, shift);

	# --- get the vars hash to aviod innecessary calls to self ---
	my $vars = $self->{$_cfgkey} ||= {};

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

# === Hash Tie Stuff ========================================================
sub TIEHASH  { bless $_[1] || {}, ref($_[0]) || $_[0] }
sub CLEAR    { delete @{$_[0]}{keys %{$_[0]}} }
sub DELETE   { delete $_[0]->_selfflatten->{$_[1]} }

sub EXISTS {
	my ($self, $key) = (shift, shift);

	# --- special keys ---
	return 1 if $key =~ /$_cfgkey$/;  # filter internal config

	# --- force flatten if the key does not exist ---
	$self->_selfflatten(exists $self->{$key} ? 0 : 1);

	return exists $self->{$key};
}

sub STORE {
	my ($self, $key, $value) = @_;

	# --- mark the object as not flat if we're storing a hash or array ref ---
	$self->_isflat(0)
		if $key ne $_cfgkey and
			_isa($value, 'HASH', 'ARRAY');

	# --- set the value and return ---
	return $self->{$key} = $value;
}

sub FETCH {
	my ($self, $key) = (shift, shift);

	# --- special keys ---
	return $self if $key eq "_untied $_cfgkey";    # return untied hash
	return $self->{$_cfgkey} if $key eq $_cfgkey;  # filter internal config

	# --- force flatten if the key does not exist ---
	$self->_selfflatten(exists $self->{$key} ? 0 : 1);

	return $self->{$key};
}

sub FIRSTKEY {
	my $self = shift->_selfflatten;

	# --- reset to first key ---
	scalar keys %{$self};

	# --- return next exposed key ---
	while (my ($key, $value) = each %{$self}) {
		return (wantarray ? ($key, $value) : $key)
			unless $key eq $_cfgkey;  # filter internal config
	}

	return undef;
}
sub NEXTKEY  {
	# --- return next exposed key ---
	while (my ($key, $value) = each %{$_[0]}) {
		return (wantarray ? ($key, $value) : $key)
			unless $key eq $_cfgkey;  # filter internal config
	}
	return undef;
}

=head1 NAME

HashRef::Flat - converts datastructure to a flattened hash

=head1 SYNOPSIS

Functional Interface:

  use HashRef::Flat qw( merge flatten unflatten interpolate )

  my $flatobj  = mkflat($nested);                # returns object
  my $flat     = flatten($nested);               # returns hash
  my $nested   = unflatten($flat);               # unflattens hash
  my $rendered = interpolate($flat, $template);  # variable interpolation

OO Interface:

  use HashRef::Flat;

  # --- create object ---
  my $obj = new HashRef::Flat($myhash);

  # --- add more data ---
  $obj->{a}{b} = 'foo';     # new key: 'a.b'
  $obj->{c}[0] = 'bar';     # new key: 'c:0'
  $obj->{d}[1]{e} = 'boo';  # new key: 'd:1.e'

  # --- merge another hash on top of the current one ---
  $obj->merge($myotherhash};

  # --- convert back to nested datastructure ---
  my $hash = $obj->unflatten;

  # --- variable interpolation ---
  my $rendered = $obj->interpolate($template);

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
  print '$hash = '. Dumper(flatten($nested));
  # --- flatten to an object ----
  print '$obj = '.  Dumper(mkflat($nested));

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
the object's behavior.

=head1 FUNCTIONAL INTERFACE

=over 2

=item B<flatten>(I<HASH>)

This returns an unblessed flattened version of I<HASH>.
OO functions are not available for the returned hash.

=item B<mkflat>(I<HASH> [,...])

This returns a blessed hash (i.e. object) containing the merged I<HASH>es
given as parameters.
Without parameters, it acts as a simple constructor.

=item B<unflatten>(I<HASH>)

Returns the flattened I<HASH> to a nested datastructure.
This is identical to the OO method of the same name.
See unflatten() in L</Methods> for additional details.

=item B<interpolate>(I<HASH>, I<TEXT>))

Allows you to interpolate the contents of a hash into a given block of text.
This is identical to the OO method of the same name.
See interpolate() in L</Methods> for additional details.

=back

=head1 OO INTERFACE

Using B<HashRef::Flat> as an object gives additional functionality including
the ability to add values to the flattened hash on the fly.

This example shows how adding values to the object converts incoming
datastructures into their respective flattened key/value pairs:

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

Valid I<OPTIONS> are 'ArrayDelim|AD => I<ARRAYDELIMITER>' and
'HashDelim|HD => I<HASHDELIMITER>'.

Constructor parameters are case insensitive and can be shortened up to first
non-unique character, though is recommended to use longer strings to avoid
conflicts with parameters that may be implemented in future versions of this package.

See L</Accessors> for details on what these parameters do.

=back

=head2 Accessors

=over 2

=item $obj->B<ad>([I<ARRAYDELIMITER>])

=item $obj->B<arraydelim>([I<ARRAYDELIMITER>])

=item $obj->B<hd>([I<HASHDELIMITER>])

=item $obj->B<hashdelim>([I<HASHDELIMITER>])

These accessors allow you to get/set the delimiters used for flattening
hashes and arrays.

Called without parameters, they return the current delimiter.
With a parameter, they set the value to be used as the delimiter.
If you use C<undef> as the parameter, they reset the delimiter to the default value.
You may use multi-character strings as delimiters.

Delimiters should be set before seeding values into the hash.
See L</CAVEATS> for more details.

Both accessors return the value of the current delimiter.
Default delimiters are '.' for hashes and ':' for arrays.

=item $obj->B<adhd>([I<ARRAYDELIMITER>, I<HASHDELIMITER>])

Sets/gets the current array and hash delimieters in a single call.
Note that unlike the accessors above, using C<undef> will not reset the
delimieters to default values.

Returns an array containing the array and hash delimieters, in that order.

=back

=head2 Methods

=over 2

=item $obj->B<merge>([I<HASH> [,...]])

This methods merges the given hashes into the object and then flatten the
contents of the object.

Merging is useful for when you have, for example, multiple configuration
files where you want each successive file's values to clobber the values of
the previous file.
In this case, you would load each file into a datastructure and then merge
its contents into the object.

Example pseudocode:

  my $cfg1 = readfile('config1');  # master application config
  my $cfg2 = readfile('config2');  # host-specific config
  my $cfg3 = readfile('config3');  # environment-specific config

  my $obj = new HashRef::Flat($cfg1);
  $obj->merge($cfg2, $cfg3);

or alternately for tha last few lines:

  my $obj = mkflat($cfg1, $cfg2, $cfg3);

If called without parameters, only the self-flattening operation will be performed.

Returns C<$obj>

=item $obj->B<unflatten>

Returns a nested hash based on the values stored in the object.
i.e. the opposite of flatten.

Note that if your keys contain character sequences the same as the
delimiters, the returned data structure will differ from the original.
For example:

  $x->{versionmap}{'2.1.5:2'} = '2.6';

Will flatten to

  $y->{'versionmap.2.1.5:2'} = '2.6';

and wil unflatten to:

  $y->{versionmap}{2}{1}{5}[2] = '2.6';

See L</CAVEATS> for additional gotchas.

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

  If you find ${name} walking around aimlessly,
  please return them to:

    ${home.address:0} ${home.address:1}
    ${home.city}, ${home.state} ${home.zip}

you can write (pseudo)code that looks like this:

  my $info = merge readYAML('myaddress.yaml');
  my $template = readfile 'lostperson.txt';
  print $info->interpolate($template);

(You can figure out the output yourself)

The format is simple: a flattened key inside of a dollar-curley bracket.
Any keys that are not in the object/hash remain unrendered.

=item $obj->B<untied>

Returns the untied, unblessed object.

This is mostly useful for development and debugging.
It exposes the hidden keys used for configuration of the object.

=back

=head1 CAVEATS

=over 2

=item B<Setting Delimiters After Seeding>

If you change delimiters after seeding values into the object, existing
flattened keys will not be converted to use the new delimiters.
For example:

  $obj->{k1}{1}[0] = 'v1.1:0';
  $obj->adhd('>', '-');
  $obj->{k1}{1}[0] = 'v1>1-0';

produces the hash:

  { 'k1.1:0' => 'v1.1:0',
    'k1-1>0' => 'v1>1-0' }

=item B<Merging vs. Assigning>

The process of merging hashes allows you to avoid nasty errors when forcing
one datatype to replace another.
The last value encountered always overrides existing values.
For example:

  $obj->merge({ k1 => { 1 => 'v1.1' }}, { k1 => 'v1' });
  $obj->merge({ k2 => 'v2' }, { k2 => { 1 => 'v2.1' }});

produces this flattened structure:

  { 'k1' => 'v1', 'k2.1' => 'v2.1' }

If you try to do the same via assignment:

  $obj->{k1}->{1} = 'v1.1';
  $obj->{k1} = 'v1';         # this works!
  $obj->{k2} = 'v2';
  $obj->{k2}->{1} = 'v2.1';  # ERROR!

The first two lines work fine, but the last line forces Perl to throw the
error, "Can't use string ("v2") as a HASH ref ..."
Alternately, you could directly assign each flattened value like this:

  $obj->{'k1.1'} = 'v1.1';
  $obj->{'k1'}   = 'v1';
  $obj->{'k2'}   = 'v2';
  $obj->{'k2.1'} = 'v2.1';

but it will not clobber higher order keys the way it would if you had merged
two datastructures.
Instead, you would get this:

  { 'k1' => 'v1', 'k1.1' => 'v1.1',
    'k2' => 'v2', 'k2.1' => 'v2.1' }

If that's what you intended, then happiness will ensue - though be warned:
this will not fully unflatten.
(see next caveat)

=item B<Unflattening an Invalid Nested Structure>

B<HahsRef::Flat> will allow you to insert keys that will not unflatten to a
valid nested structure.
For example:

  $obj->{'k1'}   = 'v1';
  $obj->{'k1.1'} = 'v1.1';
  my $hash = $obj->unflatten;
  print Dumper($hash);

gives the following warning and output:

  warning: conflict while trying to unflatten 'k1'
  { 'k1' => 'v1' }

The unflattening process happens in the sort order of the keys.
The first key processed always wins.

=item B<Storing Empty Hashes and Arrays>

Under certain circumstances, a flattened hash may momentarily contain hash
and array refs as values.
This is a requirement due to the order that Perl evaluates operations while
creating nested structures for code such as the following:

  # --- not auto-flattened on store ---
  $obj->{k1}->{1} = 'v1.1';
  $obj->{k2}->[0] = 'v2:0';

This code will perform the same thing, but will automatically be flattened when stored:

  # --- auto-flattened on store ---
  $obj->{k1} = { 1 => 'v1.1' };
  $obj->{k2} = [ 'v2:0' ];

In both cases, the object will become flat the next time the object is accessed.

On the other hand, manually adding an empty hash or array ref will return the
ref until it contains values:

  $obj->{k1} = {};          # insert {} into obj
  $hash = $obj->{k1};       # returns {}
  $hash->{1} = 'v1.1';      # add values into hash
  $value = $obj->{'k1'};    # returns undef (deleted on flatten)
  $value = $obj->{'k1.1'};  # returns 'v1.1'

=item B<Caution re. Large Datasets>

Due to the heavy internal processing of dynamic flattening, certain
operations may be time consuming when a large number of flattened keys are in
the dataset.

The following times were recorded for 1,000,000 key hash on a 2009 MacBook Pro:

  # --- new / mkhash / merge: 12.40 seconds ---
  my $obj mkflat({ array => [( 0 .. 1000000 )] });

  # --- store, indirect: 13.76 seconds ---
  $obj->{foo}->{bar} = 'foobar';

  # --- keys + delete: 2.02 seconds ---
  delete $obj->{(keys %$obj)[0]};

These bits of code were also tested with no notable penalty:

  delete $obj->{'array:0'};         # delete
  each %$obj; keys %$obj;           # each / keys
  $obj->{foo} = {bar => 'foobar'};  # store hash, direct
  $obj->{foo} = 'foobar';           # store scalar

Other operations were not tested.

=item B<We are Threadsafe!>

No caveat here.
Just a declaration :)

=back

=head1 TODO, KNOWN ISSUES AND BUGS

Most of this stuff is things I simply havn't gotten around to doing.

=over 2

=item B<BUG/TODO: Detect recursive structures>

Let's not get into an infinite loop here.

=item B<TODO: Do cool stuff with scalar/code refs>

See Hash::Flatten and the cool stuff it does.

=item B<TODO: Allow escapes in templates>

There is a use case where we may want to keep variables in templates
uninterpolated.
We should provide a mechanism for that.

On the other hand, there's a buttload of other features we could provide as well.
Perhaps we should take this functionality out of the package and create
another bundle of awesomness just for templating.

=back

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
copyright (c) BBC 2005, distributed under the GNU GPL.

=head1 DEPENDENCIES

Exporter(3pm)

=head1 SEE ALSO

perldata(1),
Hash::Flatten(3pm),

=cut

1;
