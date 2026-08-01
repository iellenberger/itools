#!/usr/bin/perl -w
use lib qw( .. );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use iTools::FileSystem qw( ls normpath );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my $file = ".file.test.$$";

# === normpath() Tests ======================================================
print "\nnormpath() Tests:\n";

# --- in/out pairs for normpath() tests ---
my @pathpairs = qw(
	.                  .
	./                 .
	.//                .

	one                one
	./one              one
	././one            one
	././one/.          one
	././one/./.        one
	././one/././       one
	./one/././         one
	one/././           one
	one/./             one
	one/               one

	one/two            one/two
	one//two           one/two
	one/./two          one/two
	one/././two        one/two
	one//.//.//two     one/two
	one//.//.//two/    one/two
	one/././two/       one/two
	one/./two/         one/two
	one//two/          one/two
	one/two/           one/two

	/                  /
	/.                 /
	/..                /
	/../..             /
	/..//../           /
	/.././../          /
	/../../.           /
	/./../../          /

	/../one            /one
	/../../one         /one
	/../../one/two     /one/two
	/../one/../two     /two
	/../one/../../two  /two
	/../one/two        /one/two
	/one/two           /one/two
	/one/../two        /two
	/one/../two        /two
	/one               /one

	one/..             .
	one/../..          ..
	one/../two         two
	one/../../two      ../two
	one/../../../two   ../../two

	../one             ../one
	./../one           ../one
	./one/../two       two
);

for (my $ii = 0; $ii < @pathpairs; $ii += 2) {
	my $in  = $pathpairs[$ii];
	my $out = $pathpairs[$ii + 1];
	my $norm = normpath($in);
	my $message = $norm eq $out
		? sprintf("%17s -> %s", $in, $norm)
		: sprintf("%17s -> %-10s (should be: %s)", $in, $norm, $out);
	tprint $norm eq $out, $message;
}

my $dirlist = ls('.', 'rd');
#print Dumper($dirlist);
print join "\n", sort keys %$dirlist;

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
