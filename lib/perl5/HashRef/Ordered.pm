package HashRef::Ordered;
use base Exporter;

use Data::Dumper; $Data::Dumper::Indent = '1';  # for debugging only

@EXPORT = qw( orderedhash );
$VERSION = "0.1";
$CLOBBER = 0;

use strict;

sub orderedhash { return new HashRef::Ordered(@_); }

# --- object contructor ---
sub new {
	# --- a hellofan effort to get a blessed obj ref to a tied hash! ---
	my $this = shift;                    # get classname or ref to instantiated object
	my $class = ref($this) || $this;     # get classname from ref if necessary
	my %hashtie = ();                    # create a hash to tie
	tie %hashtie, $class;                # tie hash to class (for hash tie)
	my $self = bless \%hashtie, $class;  # bless ref to tied hash into class (for object)

	# --- store initial key/values ---
	while (@_) {
		my ($key, $value) = (shift, shift);
		$self->{$key} = $value;
	};

	return $self;
}

# === hash tie stuff ========================================================

# --- hash constructor ---
sub TIEHASH {
	my ($this, $hash) = (shift, shift || {});
	my $class = ref($this) || $this;

	$hash->{key}   = [];
	$hash->{value} = [];
	$hash->{index} = -1;
	$hash->{clobber} = eval "\$${class}::CLOBBER";

	return bless $hash, $class;
}

sub STORE {
	my ($self, $key, $value) = @_;

	# --- set the internal value if it's using 'local.' ---
	if ($key =~ /^local\.(.*?)$/) {
		$self->{$1} = $value;
		return $value;
	}

	if ($self->{clobber}) {
		# --- find first instance of key ---
		my $index = -1;
		for (my $ii = 0; $ii < @{$self->{key}}; $ii++) {
			if ($self->{key}->[$ii] eq $key) {
				$index = $ii;
				last;
			}
		}

		# --- key does not exist, so add ---
		if ($index == -1) {
			push @{$self->{key}}, $key;
			push @{$self->{value}}, $value;
			return $value;
		}

		# --- delete all buy one instance of key ---
		for (my $ii = @{$self->{key}} - 1; $ii > $index; $ii--) {
			# --- not a matching key ---
			next unless $self->{key}->[$ii] eq $key;
			# --- delete the key and value ---
			splice @{$self->{key}}, $ii, 1;
			splice @{$self->{value}}, $ii, 1;
		}

		# --- replace the key and value ---
		$self->{key}->[$index] = $key;
		$self->{value}->[$index] = $value;

	} else {
		# --- store the key and value on the list ---
		push @{$self->{key}}, $key;
		push @{$self->{value}}, $value;
	}

	# --- return the value ---
	return $value;
}

sub FETCH  {
	my ($self, $key) = @_;

	# --- return the internal value if it's using 'local.' ---
	if ($key =~ /^local.(.*?)$/) {
		return undef unless exists $self->{$1};
		return $self->{$1};
	}

	# --- no entries yet ---
	return undef unless @{$self->{key}};

	# --- are we looking for a specific value? ---
	return $self->{value}->[$self->{index}]
		if $self->{index} >= 0
			&& $self->{index} < @{$self->{key}}
			&& $self->{key}->[$self->{index}] eq $key;

	$self->{index} = -1;
	# --- find the values ---
	my @value = ();
	for (my $ii = 0; $ii < @{$self->{key}}; $ii++) {
		push @value, $self->{value}->[$ii] if $self->{key}->[$ii] eq $key;
	}

	# --- return the values ---
	return undef unless @value;
	return @value > 1 ? \@value : $value[0];
}

sub EXISTS {
	my ($self, $key) = @_;

	# --- no entries yet ---
	return undef unless @{$self->{key}};

	# --- find the values ---
	foreach my $selfkey (@{$self->{key}}) {
		return 1 if $selfkey eq $key;
	}

	# --- no key found ---
	return undef;
}

sub FIRSTKEY {
	my $self = shift;

	# --- no entries yet ---
	return undef unless @{$self->{key}};

	# --- return the first key ---
	$self->{index} = 0;
	return $self->{key}->[0];
}

sub NEXTKEY {
	my ($self, $lastkey) = @_;

	# --- no entries yet ---
	return undef unless @{$self->{key}};

	# --- no FIRSTKEY ---
	return undef if $self->{index} == -1;

	# --- passed last element ---
	if ($self->{index} >= @{$self->{key}}) {
		$self->{index} = -1;
		return undef;
	}

	# --- return the key ---
	return $self->{key}->[++$self->{index}];
}

sub CLEAR {
	my $self = shift;

	$self->{key}   = [];
	$self->{value} = [];
	$self->{index} = -1;
}

sub DELETE {
	my ($self, $key) = @_;

	# --- delete if index is on the same key ---
	if ($self->{index} >= 0 && $self->{index} < @{$self->{key}}
			&& $self->{key}->[$self->{index}] eq $key) {
		my $value = $self->{value}->[$self->{index}];

		splice @{$self->{key}}, $self->{index}, 1;
		splice @{$self->{value}}, $self->{index}, 1;
		$self->{index}--;

		return $value;
	}

	# --- delete all keys in clobber mode ---
	if ($self->{clobber}) {
		my @value = ();
		# --- delete each instance of the key ---
		for (my $ii = @{$self->{key}} - 1; $ii >= 0; $ii--) {
			next unless $self->{key}->[$ii] eq $key;  # non-matching key
			push @value, $self->{value}->[$ii];       # keep values for return
			splice @{$self->{key}}, $ii, 1;           # delete the key
			splice @{$self->{value}}, $ii, 1;         # delete the value

			# --- roll back index if past deleted key ---
			$self->{index}-- if $self->{index} > $ii;
		}
		# --- one last test to make sure index is not too far forward ---
		$self->{index}-- if $self->{index} >= @{$self->{key}};

		return @value;
	}

	# --- delete the first instance of the key ---
	for (my $ii = 0; $ii < @{$self->{key}}; $ii++) {
		next unless $self->{key}->[$ii] eq $key;

		my $value = $self->{value}->[$ii];

		splice @{$self->{key}}, $ii, 1;
		splice @{$self->{value}}, $ii, 1;
		$self->{index}-- if $ii <= $self->{index};

		return $value;
	}

	# --- no key found ---
	return undef;
}

# === Methods for walking hash ==============================================

sub getindex { return shift->{'local.index'} || -1; }
sub length { return scalar @{shift->{'local.key'}}; }

sub reset  { return shift->{'local.index'} = -1; }
sub rewind { return shift->{'local.index'} =  0; }

sub first {
	my $self = shift;

	# --- no entries yet ---
	return undef unless @{$self->{'local.key'}};

	# --- return the first key ---
	$self->{'local.index'} = 0;

	# --- return the key (or key, value, index)---
	return wantarray
		? ( $self->{'local.key'}->[0], $self->{'local.value'}->[0], 0)
		: $self->{'local.key'}->[0];
}

sub next {
	my $self = shift;

	# --- no entries yet ---
	return undef unless @{$self->{'local.key'}};

	# --- no FIRSTKEY ---
	return undef if $self->{'local.index'} == -1;

	# --- passed last element ---
	if ($self->{'local.index'} >= @{$self->{'local.key'}}) {
		$self->{'local.index'} = -1;
		return undef;
	}

	# --- get the next index value ---
	my $index = ++$self->{'local.index'};

	# --- return the key (or key, value, index)---
	return wantarray
		? ( $self->{'local.key'}->[$index], $self->{'local.value'}->[$index], $index )
		: $self->{'local.key'}->[$index];
}

sub last {
	my $self = shift;

	# --- no entries yet ---
	return undef unless @{$self->{'local.key'}};

	my $index = $self->{'local.index'} = @{$self->{'local.key'}} - 1;

	# --- return the key (or key, value, index)---
	return wantarray
		? ( $self->{'local.key'}->[$index], $self->{'local.value'}->[$index], $index )
		: $self->{'local.key'}->[$index];
}

# === Clobber Methods =======================================================

# --- get/set clobber mode ---
sub setclobber { return shift->clobber(@_); }
sub noclobber { return shift->clobber(0); }
sub clobber {
	my ($self, $clobber) = @_;
	$self->{'local.clobber'} = $clobber if defined $clobber;
	return $self->{'local.clobber'};
}

# --- methods for using clobber as a stack ---
sub pushclobber {
	my ($self, $clobber) = @_;

	return $self->clobber unless $clobber;
	$self->{'local.clobberstack'} = []
		unless ref $self->{'local.clobberstack'} eq 'ARRAY';

	push @{$self->{'local.clobberstack'}}, $self->clobber;
	return $self->clobber($clobber);
}
sub popclobber {
	my $self = shift;

	$self->{'local.clobberstack'} = []
		unless ref $self->{'local.clobberstack'} eq 'ARRAY';

	return $self->clobber unless @{$self->{'local.clobberstack'}} > 0;

	my $clobber = pop @{$self->{'local.clobberstack'}};
	return $self->clobber($clobber);
}


# --- deletes all instances of a key - same as DELETE with clobber ---
sub clear {
	my ($self, $key) = @_;

	# --- clear everything if there's no key ---
	unless (defined $key) {
		%$self = () unless $key;
		return;
	}

	# --- turn on clobber and delete ---
	$self->pushclobber(1);
	my @value = delete $self->{$key};
	$self->popclobber;

	# --- return deleted values ---
	return @value;
}

# --- stores a key, replace if necessary - same as STORE with clobber ---
sub store {
	my ($self, $key, $value) = @_;

	# --- turn on clobber and store ---
	$self->pushclobber(1);
	$self->{$key} = $value;
	$self->popclobber;

	return $value;
}

# === Imcomplete Stuff ======================================================

# --- insert and append take indicies. same function as vi ---
sub insert {}
sub append {}

sub push {}
sub pop {}
sub shift {}
sub unshift {}

=head1 NAME

HashRef::Ordered - utility for creating ordered hashes

=head1 SYNOPSIS

 use HashRef::Ordered qw( orderedhash );

 my $newhash = orderedhash( key => 'value', ... );
 $newhash->{anotherkey} = $value;

=head1 DESCRIPTION

This is a wicked little class that returns hash keys in the order that
they were created.


=head1 TODO

CONVERSION! - make this look like other iTools code

=head1 COPYRIGHT

Copyright (c) 2001-2004 by Ingmar Ellenberger.

Distributed under The Artistic License.  For the text of this license,
see http://puma.site42.com/license.psp or read the file LICENSE in the
root of the distribution.

=cut

1;
