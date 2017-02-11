#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/../..");

use Data::Dumper; $Data::Dumper::Indent = 1; # for debugging only
use iTools::Core::Test;

use Puma::Tools::Capture qw( capture );

use strict;

# === Globals and Constants =================================================
my (
	$capture, $results,
);

# ===========================================================================
print "\nConstructor:\n";
tprint($capture = new Puma::Tools::Capture, "object construction");

print "\nUsing startCapture() and endCapture():\n";
tprint($capture->startCapture, "capture started");
tprint($results = $capture->endCapture(), "capture ended");
print $results;
tprint($results =~ /capture started/ms, "capture verified");

# ---------------------------------------------------------------------------
#print "\nUsing capture() Method:\n";
#$results = $capture->capture(
#	sub { print "capture method" }
#);
#tprint($results =~ /capture method/ms, "capture verified");

# ---------------------------------------------------------------------------
print "\nUsing capture() Export:\n";
$results = capture { print "capture export" };
tprint($results =~ /capture export/ms, "capture verified");

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
