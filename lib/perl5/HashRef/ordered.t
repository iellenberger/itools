#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/..");

use Data::Dumper; $Data::Dumper::Indent=$Data::Dumper::Sortkeys=$Data::Dumper::Terse=1; # for debugging only
use iTools::Core::Test;
use HashRef::Ordered qw( orderedhash );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $hash );

# ---------------------------------------------------------------------------

print "\nConstructor/Export:\n";
$hash = orderedhash(
	negtwo => '-II',
	negone => '-I',
);
# print _indent(Dumper($hash)) ."\n";
tprint $hash, "hash created";
tprint $hash->{negtwo} eq '-II' && $hash->{negone} eq '-I', "found seeded values";

# ---------------------------------------------------------------------------

print "\nPopulate the hash:\n";
_populate($hash);
tprint $hash->length == 13, "hash population";

# ---------------------------------------------------------------------------

print "\nIndex tests:\n";
print "   resetting index:\n";
print "      before: ". $hash->getindex ."\n";
$hash->reset;
print "      after : ". $hash->getindex ."\n";
print "      length : ". $hash->length ."\n";
tprint $hash->getindex == -1, "index reset";

# ---------------------------------------------------------------------------

print "\nWalking the hash:\n";
my ($key, $value, $index) = $hash->first();
while ($key) {
	print "   [$index]\t$key\t$value\n";
	($key, $value, $index) = $hash->next();
}
print "\n";

# ---------------------------------------------------------------------------

print "\nDelete single element:\n";
print "   deleting three => '". delete($hash->{three}) ."'\n";
tprint !$hash->{three}, "deleting element 'three'";

# ---------------------------------------------------------------------------

print "\nDelete single key with multiple elements, one at a time:\n";
my $zerocount = ref $hash->{zero} ? @{$hash->{zero}} : 1;
print "   deleting $zerocount elements\n";
for (my $ii = 0; $ii < $zerocount; $ii++) {
	my $value = delete $hash->{zero};
	print "      deleted zero => '$value'\n";
}
tprint !$hash->{zero}, "deleting element 'zero'";

# ---------------------------------------------------------------------------

print "\nDelete single key with multiple elements, all at once:\n";
clear $hash('one'); # alternate syntax: $hash->clear('one');
tprint !$hash->{one} && $hash->{two}, "using 'clear \$hash(\"one\")'";

# ---------------------------------------------------------------------------

print "\nClearing hash:\n";

clear $hash;
tprint !scalar(%$hash), "using 'clear \$hash'";
print "      repopulating for next test ...\n";
_populate($hash);
%$hash = ();
tprint !scalar(%$hash), "using '\%\$hash = ()'";

# ---------------------------------------------------------------------------

print "\nTurning clobber mode on:\n";
print "   before: ". clobber $hash .", ";
clobber $hash(1);
print "after : ". clobber $hash ."\n";
tprint clobber $hash, "enable clobber mode";

# ---------------------------------------------------------------------------

print "\nRepopulate the hash in clobber mode:\n";
_populate($hash);
# print _indent(Dumper($hash));
tprint $hash->length == 9, "hash population";

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');

# === Subs ==================================================================

sub _populate {
	my $hash = shift;

	$hash->{negtwo} = '-II' unless defined $hash->{negtwo};
	$hash->{negone} = '-I' unless defined $hash->{negone};
	$hash->{zero}  = 'nullus';
	$hash->{one}   = 'I';
	$hash->{two}   = 'II';
	$hash->{three} = 'III';
	$hash->{zero}  = 'nullus, part 2';
	$hash->{one}   = 'I, part 2';
	$hash->{four}  = 'IV';
	$hash->{five}  = 'V';
	$hash->{six}   = 'VI';
	$hash->{zero}  = 'nullus, part 3';
	$hash->{one}   = 'I, part 3';

	return $hash;
}

sub _test {
	my ($condition, $message) = @_;
	return "   SUCCESS: $message" if $condition;
	return "   TEST FAILED: $message";
}

sub _indent {
	my $text = shift;
	$text =~ s/^/   /mg;
	return $text;
}

1; # not necessary, but good habit
