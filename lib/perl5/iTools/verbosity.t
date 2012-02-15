#!/usr/bin/perl -w
use lib qw( .. );

use Data::Dumper; $Data::Dumper::Indent=0; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;
use iTools::Verbosity;
use Symbol;

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================

# --- the logfile we're gonna parse through to validate output ---
my $logfile = 'verbosity.tmp.log';
my $logfh;

# === Tests =================================================================
# --- for all our tests, we direct all output to a file for later analysis ---
print "\nLogging Setup:\n";
tprint unlink($logfile), "removing old logfile '$logfile'"
	if -e $logfile;
tprint vlogfile($logfile) eq $logfile, "log filename set via vlogfile('$logfile')";
tprint verbosity(-3) == -3, "verbosity set to -3 (all output will go to logfile";
tprint vloglevel(0) == 0, "log verbosity set to 0";

print "\nBasic Verbosity Tests:\n";
tprint vlog(0, "log0 v0\n"), "vprint(0) w/o indent";
tprint logmatch('^log0 v0$'), "   validated";
tprint vlog(0, ">log0 v0 indent\n"), "vprint(0) with indent";
tprint logmatch('^log0 v0 indent$'), "   validated";
tprint !vlog(1, "log0 v1\n"), "vprint(1)";
tprint logmatch('.*') == -1, "   validated";

print "\nBasic Verbosity Tests:\n";
tprint vloglevel(1) == 1, "log verbosity set to 1";
tprint vlog(0, "log1 v0\n"), "vprint(0) w/o indent";
tprint logmatch('^log1 v0$'), "   validated";
tprint vlog(0, ">log1 v0 indent\n"), "vprint(0) with indent";
tprint logmatch('^log1 v0 indent$'), "   validated";
tprint vlog(1, "log1 v1\n"), "vprint(1)";
tprint logmatch('^log1 v1$'), "   validated";
tprint vlog(1, ">log1 v1 indent\n"), "vprint(1) with indent";
tprint logmatch('^   log1 v1 indent$'), "   validated";

print "\nCleanup:\n";
tprint close($logfh), "closing logfile '$logfile'"
	if $logfh;
tprint unlink($logfile), "removing logfile '$logfile'"
	if -e $logfile;

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');

# === Utility Functions =====================================================
sub logmatch {
	my $regex = shift || 'LOGMATCHERROR';

	# --- open logfile if necessary ---
	unless ($logfh) {
		$logfh = gensym;
		open $logfh, $logfile;
	}

	# --- read a line, return -1 on failure ---
	my $line = <$logfh>;
	return -1 unless $line;

	# --- trim the line ---
	chomp $line;
	$line =~ s/^\[[^\]]*?\]\s//;

	# --- test the line ---
	return $line =~ /$regex/ ? 1 : 0;
}
