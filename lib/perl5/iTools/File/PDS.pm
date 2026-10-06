package iTools::File::PDS;
$VERSION = "1.0.0";

use Exporter 'import';
@EXPORT_OK = qw(
	readPDS writePDS
);

use Data::Dumper;
use iTools::File qw(readfile writefile);

use strict;
use warnings;

# === PDS File Handling =====================================================
# --- read a perl data structure from a file ---
sub readPDS {
	my $filename = shift;

	# --- preset/declare a few things ---
	$iTools::File::Die = -1; # make readfile() fail quietly

	# --- read the file ---
	my $content = readfile $filename;
	return {} unless $content; # no content read

	# --- convert to PDS and return ---
	my $VAR1;
	eval "\$VAR1 = $content;"; warn $@ if $@;
	return $VAR1;
}

# --- write a perl data structure to a file ---
sub writePDS {
	my ($filename, $data) = (shift, shift);

	# --- preset/declare a few things ---
	$iTools::File::Die = -1; # make readfile() fail quietly

	# --- write the file ---
	local $Data::Dumper::Purity=1;
	local $Data::Dumper::Terse=1;
	local $Data::Dumper::Indent=0;
	return writefile ">$filename", Dumper($data);

	return $data;
}

1;
