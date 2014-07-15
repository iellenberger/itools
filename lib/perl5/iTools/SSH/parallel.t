#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use FindBin qw( $RealBin $RealScript );
use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;
use iTools::Verbosity qw( verbosity );

use iTools::SSH::Parallel;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my ( $obj, $retval );
my @hosts = qw(
	df5-1
	df5-2 df5-3 df5-4 df5-5 df5-6 df5-7 df5-8 df5-9
	df5-10 df5-11 df5-12 df5-13 df5-14 df5-15 df5-16 df5-17 df5-18 df5-19
	df5-20 df5-21 df5-22 df5-23 df5-24 df5-25 df5-26 df5-27 df5-28 df5-29
	df6-1 df9-1 df11-4 df99-99
);

verbosity(1);

# === Constructor Tests =====================================================
print "\nObject Construction:\n";

$obj = new iTools::SSH::Parallel(
	Hosts => \@hosts,
	Timeout => 5,
	Rate => 10,
);
tprint $obj, "object created via new()";
tprint ref $obj eq 'iTools::SSH::Parallel', "object class 'iTools::SSH::Parallel'";
$retval = tprint $obj->VERSION && $iTools::SSH::Parallel::VERSION, "locating version identifier";
tprint $obj->VERSION eq $iTools::SSH::Parallel::VERSION, "class version $iTools::SSH::Parallel::VERSION"
	if $retval;

$obj->run('"sleep $[ ($RANDOM % 5) + 1 ]; ls -d /opt1"');
#print Dumper($obj);

my $hosthash = $obj->hosthash;
print "\n";
foreach my $host (@hosts) {
	if ($hosthash->{$host}->{status}) {
		print "$host exited with status $hosthash->{$host}->{status}\n   $hosthash->{$host}->{stderr}\n";
	} elsif ($hosthash->{$host}->{stderr}) {
		print "$host sent message to STDERR\n   $hosthash->{$host}->{stderr}\n";
	}
}

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
