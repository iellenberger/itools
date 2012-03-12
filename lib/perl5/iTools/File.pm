package iTools::File;
use base Exporter;
$VERSION="1.0.0";

@EXPORT_OK = qw( readfile writefile );

use Carp qw( cluck confess );
use Symbol;

use strict;
use warnings;

# === Package Variables =====================================================
# --- die or not? ---
our $Die = 1;

# === Read a file, return the contents ======================================
sub readfile {
	# --- grab filename (required parameter) ---
	my $filename = shift
		or return _die('readfile: no file name supplied');

	# --- open file or throw error ---
	my $fh = gensym(); open $fh, $filename
		or return _die("readfile: could not open '$filename'");

	# --- read file contents ---
	my $content = ''; { local $/; $content = <$fh>; } # read contents

	# --- close file and return contents ---
	close $fh; ungensym($fh);
	return $content;
}

# === Write (create/overwrite) a file =======================================
sub writefile {
	# --- get filename and content ---
	my ($filename, $content) = (shift, shift || '');
	return _die('writefile: no filename given')
		unless $filename;

	# --- parse mode from filename ---
	my $mode = '>'; if ($filename =~ /^(>+)(.*)$/) { ($mode, $filename) = ($1, $2) }

	# --- make a directory list ---
	my @dirs = split /\//, $filename;                                  # split path into components
	if ($filename =~ /^\//) { shift @dirs; $dirs[0] = '/'. $dirs[0]; } # correction for blank entry if '^/'
	pop @dirs;                                                         # remove the file name

	# --- create parent directories ---
	my $path;
	foreach my $dir (@dirs) {
		$path = ($path ? $path .'/' : ''). $dir; next if -d $path;
		return _die("writefile: could not create directory '$path' - another file is in the way")
			if -e $path;
		mkdir $path, 0755;
	}

	# --- (over)write the file ---
	my $fh = gensym();
	open $fh, "$mode$filename"
		or return _die("writefile: error opening file '$filename': $!");
	print $fh $content; close $fh; ungensym($fh);

	# --- close and return ---
	return $content;
}

# --- requires 5.10 - Ubuntu LTS 8.04 only has 5.8 ---
# use feature qw( switch );

sub _die {
#	given ($iTools::File::Die) {
#		when (0) { cluck @_ }
#		when (1) { confess @_ }
#	}
	SWITCH: {
		$iTools::File::Die == 0 && cluck @_;
		$iTools::File::Die == 1 && confess @_;
	}
	return undef;
}

1;

=head1 NAME

iTools::File - utilities for manipulating individual files

=head1 SYNOPSIS

 use iTools::File qw( readfile writefile );
 $iTools::File::Die = -1;

 my $content = readfile('filename1');
 writefile('filename2', $content);

=head1 DESCRIPTION

iTools::File provides a simple interface for reading and writing files.

=head1 EXPORTED SUBROUTINES

=over 4

=item B<readfile>(FILE)

B<readfile>() functions slurps and returns the entire contents of B<FILE>.
Note that if the file is extremely large (given available memory) this may cause problems.

=item B<writefile>(FILE, [CONTENT])

B<writefile>() writes the given B<CONTENT> to B<FILE>.
Prepend a '>>' to the filename to append content at the end of a file.
Note that appending to a file has the same memory limitations as B<readfile>().

If no B<CONTENT> is given, it will update the timestamp on the file, creating it if necessary.

Returns the B<CONTENT> written.

=back

=head1 VARIABLES

=over 4

=item B<iTools::File::Die>

Set this method to control how B<readfile>() and B<writefile>() will respons when encountering an error.

    -1   don't die, no message
     0   don't die, give stacktrace
     1   die with stacktrace (default)

=back

=head1 TODO

=over 4

=item B<Remove Append File Size Limitation>

Make the append functionality do a seek to end before write to avoid reading the contents of the file.

=item B<Using writefile() for Touching a File>

Make the touch functionality more efficient or create a separate sub.

=item B<Update for Perl 5.10+>

When Perl5.10 becomes common, update code (documented interally) for that release.

=back

=head1 KNOWN ISSUES AND BUGS

See memory limitations in B<readfile>().

=head1 REPORTING BUGS

Report bugs in the iTools' issue tracker at
L<https://github.com/iellenberger/itools/issues>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2012 by Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<https://github.com/iellenberger/itools/blob/master/LICENSE>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 DEPENDENCIES

strict(3pm), warnings(3pm),
Carp(3pm), Exporter(3pm), Symbol(3pm)

=head1 SEE ALSO

=cut
