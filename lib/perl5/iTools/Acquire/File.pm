package iTools::Acquire::File;
use base qw( iTools::Acquire::Base );
$VERSION = "0.01";

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging

use strict;
use warnings;

# === Required Method Overrides =============================================
sub fetch {
	my ($self, $uri) = @_;
	$uri = $self->uri unless defined $uri;

	# --- open the file for reading ---
	#! TODO: Add unix SMB style processing here
	my $path = $uri->path;
	open INFILE, $path or do {
		# --- error opening file: log message and return undef ---
		$self->message("Could not open '$path'\n    $!\n");
		return undef;
	};

	# --- read content and close file ---
	{ local $/; $self->content(<INFILE>) }
	close INFILE;

	# --- return content ---
	return $self->content;
}

1;
