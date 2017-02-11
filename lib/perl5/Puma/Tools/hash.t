#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent = 1; # for debugging only
use iTools::Core::Test;

use Puma::Tools::Hash qw(
	slice merge
);

use strict;

# === Globals and Constants =================================================
my (
	$hash, $slice,
	$hash1, $hash2, $hash3,
);

# === slice() Tests ========================================================
print "\nHash Slicing:\n";

$hash = { one => 1, two => 2, three => 3, four => 4 };
$slice = slice($hash, qw( two four five ));
tprint(!exists $slice->{one},   "new hash, negative test 'one'");
tprint($slice->{two}  == 2,     "new hash, positive test '2'");
tprint(!exists $slice->{three}, "new hash, negative test 'three'");
tprint($slice->{four} == 4,     "new hash, positive test '4'");
tprint(!exists $slice->{five},  "new hash, negative test 'five'");

print "\n";
$hash = { one => 'A', two => 'B', three => 'C', four => 'D' };
slice($slice, $hash, qw( three four five ));
tprint(!exists $slice->{one},   "existing hash, negative test 'one'");
tprint($slice->{two} == 2,      "existing hash, positive test '2'");
tprint($slice->{three} eq 'C',  "existing hash, positive test 'C'");
tprint($slice->{four} eq 'D',   "existing hash, positive test 'D'");
tprint(!exists $slice->{five},  "existing hash, negative test 'five'");

print "\n";
$hash = { one => 'a', two => 'b', three => 'c', four => 'd' };
slice($slice, $hash);
tprint($slice->{one} eq 'a',   "no keys, positive test 'a'");
tprint($slice->{two} eq 'b',   "no keys, positive test 'b'");
tprint($slice->{three} eq 'c', "no keys, positive test 'c'");
tprint($slice->{four} eq 'd',  "no keys, positive test 'd'");
tprint(!exists $slice->{five}, "no keys, negative test 'five'");

# === merge() Tests ========================================================
print "\nHash Merging:\n";

$hash1 = {
	one => '1',
	two => { two1 => '2.1', },
	three => '3',
	four => { four1 => '4.1', four2 => '4.2', four3 => '4.3', },
	five => '5',
	six => '6',
};
$hash2 = {
	two => { two2 => 'B.B', },
	three => 'C',
	four => { four2 => 'D.B', four3 => 'D.C', },
	five => 'E',
	six => { six1 => 'F.A', six2 => 'F.B', six3 => 'F.C', },
};
$hash3 = {
	two => { two3 => 'b.c', },
	four => { four3 => 'd.c', },
	five => 'e',
	six => 'f',
};

merge($hash1, $hash2, $hash3);
tprint($hash1->{one} eq '1', "merge one");
tprint($hash1->{two}->{two1} eq '2.1', "merge two.one");
tprint($hash1->{two}->{two2} eq 'B.B', "merge two.two");
tprint($hash1->{two}->{two3} eq 'b.c', "merge two.three");
tprint($hash1->{three} eq 'C', "merge three");
tprint($hash1->{four}->{four1} eq '4.1', "merge four.one");
tprint($hash1->{four}->{four2} eq 'D.B', "merge four.two");
tprint($hash1->{four}->{four3} eq 'd.c', "merge four.three");
tprint($hash1->{five} eq 'e', "merge five");
tprint($hash1->{six}->{six1} eq 'F.A', "merge six.one");
tprint($hash1->{six}->{six2} eq 'F.B', "merge six.two");
tprint($hash1->{six}->{six3} eq 'F.C', "merge six.three");

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
