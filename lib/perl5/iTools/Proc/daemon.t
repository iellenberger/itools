#!/usr/bin/perl -w
use lib qw( ../.. );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use Cwd;
use Data::Dumper;
use English;
use iTools::Core::Test;
use iTools::Proc::Daemon;
use Time::HiRes 'usleep';

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
my $CWD = cwd;
my $PIDFILE = "$CWD/daemon.pid";

# === Tests =================================================================
# --- run daemon sub if this is subprocess ---
myDaemon() if @ARGV > 0 && $ARGV[0] eq 'spawn';

# --- spawn the child and wait for the pidfile to be created ---
system "$0 spawn";
my $count = 0;
do { usleep 100000; $count++ } until -e $PIDFILE || $count > 100000;
my $pid = `cat $PIDFILE` + 0;  # do a math op to ensure this is a clean value
tprint $pid, "daemon spawned ($pid)";

# --- a few test on the daemon ---
my $ps = psDaemon($pid);
tprint $ps->{running}, "daemon confirmed running";
tprint $ps->{ps}->{ppid} == 1, "daemon parent = '1'";

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');

# === separate sub for daemon process =======================================
sub myDaemon {

	print "Object Creation and Daemonizing:\n\n";

	# --- create daemon object ---
	my $daemon = new iTools::Proc::Daemon();
	tprint $daemon, "Daemon object creation";

	# --- start daemon and creat pidfile ---
	$daemon->daemonize;
	system "echo $PID > $PIDFILE";

	sleep 2;

	# --- clean up pid file and exit ---
	unlink "$PIDFILE";
	exit;
}
