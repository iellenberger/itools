#!/usr/bin/perl -w

# --- local library path ---
use FindBin qw( $Bin );
use lib ("$Bin/..");

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::Core::Test;

use iTools::File qw( readfile writefile );

use strict;
use warnings;

# === Globals, Constants and Predeclarations ================================
$iTools::File::Die = -1;
my $file = ".file.test.$$";

# === readfile() Tests ======================================================
print "\nreadfile() Tests:\n";

# --- call to readfile w/o params ---
tprint !readfile(), "call to readfile() w/o parameters, intentional failure";

# --- attempt to read non existant file ---
tprint !system("rm -f $file"), "removing $file for next test";
tprint !readfile($file), "call to readfile() on non-existant file, intentional failure";

# --- create a file and read it ---
tprint !system("echo 'test' > $file"), "creating test data file '$file'";
tprint readfile($file) eq "test\n", "reading file '$file'";
tprint !system("rm $file"), "removing test data file '$file'";

# === writefile() Tests =====================================================
print "\nwritefile() Tests:\n";

# --- call to writefile w/o params ---
tprint !writefile(), "call to writefile w/o parameters, intentional failure";

# --- write to a bad filename ---
tprint !system("touch $file"), "creating test file '$file'";
tprint !writefile("$file/$file"), "call to writefile with bad dir, intentional failure";
 
# --- try to write to write-protected file ---
tprint !system("chmod 444 $file"), "making test file '$file' read-only";
tprint !writefile($file, 'test'), "writing '$file', intentional failure";
tprint !system("rm -f $file"), "removing test data file '$file'";

# --- write to file creating dir ---
tprint writefile("$file/writefile.test", 'test'), "writing '$file/writefile.test'";
tprint !system("rm -r $file"), "removing test data directory '$file'";

# === writefile() w/ append tests ===========================================
print "\nwritefile() Append Tests:\n";

# --- write new file ---
tprint writefile(">>$file", "line1\n"), "Creating '$file' with append (>>) operator";

# --- append file & test contents ---
tprint writefile(">>$file", "line2\n"), "Appending '$file'";
tprint readfile($file) eq "line1\nline2\n", "Contentes of '$file' verified";
tprint !system("rm -rf $file"), "removing test data directory '$file'";

# === Error Report ==========================================================
print "\n". tvar('errors') ." error(s) and ". tvar('warnings') ." warning(s) in ". tvar('count') ." tests\n\n";
exit tvar('errors');
