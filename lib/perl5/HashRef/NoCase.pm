package HashRef::NoCase;
use base qw( Exporter );
$VERSION = "0.02";
@EXPORT_OK = qw( nchash );

use strict;
use warnings;

# === Constructor ===========================================================

# --- exported sub ---
sub nchash { new HashRef::NoCase(@_) }

# --- real constructor ---
sub new {
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
sub clear { delete @{$_[0]}{keys %{$_[0]}} }

# === Hash Tie ==============================================================
sub TIEHASH  { bless $_[1] || {}, ref($_[0]) || $_[0] }
sub CLEAR    { delete @{$_[0]}{keys %{$_[0]}} }

sub STORE {
	my ($self, $key, $value) = @_;

	# --- search for and delete all old keys of various cases ---
	my $lckey = lc($key);
	foreach my $oldkey (keys %$self) {
		delete $self->{$oldkey} if lc($oldkey) eq $lckey;
	}
	# --- assign and return the new key ---
	return $self->{$key} = $value;
}

sub FETCH    {
	my ($self, $key) = (shift, lc shift);

	# --- return the value for the first matching key ---
	foreach my $oldkey (keys %$self) {
		return $self->{$oldkey} if lc($oldkey) eq $key;
	}
	return undef;
}

sub EXISTS   {
	my ($self, $key) = (shift, lc shift);

	foreach my $oldkey (keys %$self) {
		return 1 if lc($oldkey) eq $key;
	}
	return undef;
}

sub DELETE   {
	my ($self, $key) = (shift, lc shift);

	my $oldval;
	foreach my $oldkey (keys %$self) {
		$oldval = delete $self->{$oldkey} if lc($oldkey) eq $key;
	}
	return $oldval;
}

sub FIRSTKEY {
	my $a = scalar keys %{$_[0]};
	my $foo = each %{$_[0]};
	return $foo;
}

sub NEXTKEY  {
	my ($self, $lastkey) = @_;

	foreach my $key (keys %$self) {
		return $key unless $lastkey;
		$lastkey = '' if $key eq $lastkey;
	}
	return undef;
}

1;

=head1 NAME

HashRef::NoCase - object tie for case insensitive hashes

=head1 SYNOPSIS

use HashRef::NoCase qw( nchash );
my $hashref = nchash(%hash);
  
=head1 DESCRIPTION

B<HashRef::NoCase> creates a hash that case insensitive for lookups
while still preserving case of the keys.

=head1 EXPORTED SUBROUTINES

=over 4

=item B<nchash>([KEY => VALUE, ...])

Creates a new B<HashRef::NoCase> object, populating it with the key/value pairs passed as parameters.

=back

=head1 TODO, KNOWN ISSUES AND BUGS

None

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

Exporter(3pm)

=head1 SEE ALSO

perldata(1),
perltie(1)

=cut
