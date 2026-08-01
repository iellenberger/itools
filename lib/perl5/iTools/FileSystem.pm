package iTools::FileSystem;
use base Exporter;
$VERSION="1.0.0";

@EXPORT_OK = qw(
	ls
	filestat
	normpath
	rmrecursive
);

use Symbol;

use strict;
use warnings;

# === Directory Listing, File Status and Path Munging =======================
# --- list a file/directory ---
sub ls {
	my ($path, $flags) = (shift || '', shift || '');

	# --- not a dir ---
	return { $path => {
		name => $path,
		type => -l $path ? 'link' : 'file',
		filestat($path),
	}} unless -d $path;

	# --- parse flags ---
	my $recurse = $flags =~ /r/ ? 1 : 0;
	my $files   = $flags =~ /f/ ? 1 : 0;
	my $dirs    = $flags =~ /d/ ? 1 : 0;
	$dirs = $files = 1 unless $dirs || $files; # assume dirs and files if neither set

	# --- default values ---
	my $list = {};

	my $dh = gensym(); # create dirhandle via Symbol::gensym
	opendir $dh, $path;
	foreach my $file (readdir $dh) {
		next if $file eq '.' || $file eq '..';  # don't do something stupid
		my $name = normpath("$path/$file");

		# --- generate the hash ---
		my $type = -d $name ? 'dir' : -l $name ? 'link' : 'file';
		$name .= $type eq 'dir' ? '/' : '',
		my $filehash = { name => $name, type => $type, filestat($name) };

		# --- fileter for files and dirs ---
		if    ($dirs && $type eq 'dir')  { $list->{$name} = $filehash }
		elsif ($files && $type ne 'dir') { $list->{$name} = $filehash }

		# --- recurse subdirs ---
		if ($type eq 'dir' && !-l $name && $recurse) {
			my $innerls = ls($name, $flags);
			foreach my $innerfile (keys %$innerls) {
				$list->{$innerfile} = $innerls->{$innerfile};
	}	}	}

	closedir $dh;
	ungensym($dh); # destroy dirhandle via Symbol::ungensym
	return $list;
}

# --- get a status hash for a file ---
sub filestat {
	my ($file, $stat) = (shift, {});
	return unless $file; # return if no file

	# --- get keys and values ---
	my @statkey = qw( dev inode mode numlink uid gid rdev size atime mtime ctime blocksize blocks );
	my @statval = stat $file;

	# --- generate the stat hash ---
	for (my $ii = 0; $ii < @statkey; $ii++) {
		$stat->{$statkey[$ii]} = $statval[$ii];
	}

	# --- return stat hash/hashref ---
	return wantarray ? %$stat : $stat;
}

# --- normalize a filesystem path ---
sub normpath {
	my $inpath = shift;

	# --- save whether this is a relative or absolute path ---
	my $inabs = $inpath =~ m|^/|;

	# --- tear apart the path and process each segment ---
	my @parts;
	foreach my $segment (split '/', $inpath) {
		# --- ignore single dot and double slashes ---
		next if $segment eq '' || $segment eq '.';
		
		# --- process doubledots ---
		if ($segment eq '..') {
			if (@parts == 0) {
				# --- add '..' at the beginning of a relative path ---
				push @parts, $segment unless $inabs
			} else {
				# --- push '..' if prev segment also a '..' ---
				if ($parts[-1] eq '..') { push @parts, $segment }
				# --- else remove prev segment ---
				else { pop @parts }
			}
		} else {
			# --- if we got here, we have a valid segment ---
			push @parts, $segment;
		}
	}

	# --- reassemble the path ---
	my $path = join '/', @parts;

	# --- if path is absolute, add a prefix slash ---
	$path = "/$path" if $inpath =~ m|^/|;
	# --- use '.' if the path is empty ---
	$path = '.' if $path eq '';

	return $path;
}

# === Move, Copy and Delete =================================================
# --- remove files recursively ---
sub rmrecursive {
	foreach my $file (@_) {
		next unless -e $file;

		# --- remove dir ---
		if (-d $file) {
			my $files = ls(fr => $file);

			# --- delete the files ---
			foreach my $file2 (sort keys %$files) {
				next unless $files->{$file2}->{type} eq 'file';

				unlink "$file/$file2" or warn "Could not remove file $file/$file2";
				delete $files->{$file2};
			}
			# --- delete the dirs ---
			foreach my $file2 (sort { $b cmp $a } keys %$files) {
				rmdir "$file/$file2" or warn "Could not remove directory $file/$file2";
			}
			# --- delete the top dir ---
			rmdir "$file" or warn "Could not remove directory $file";
		} else {
			# --- remove file ---
			unlink $file or warn "Could not remove file $file";
		}
	}
}

#! TODO: make a recursive mkdir
#! TODO: make a better rename (for across filesystems)

# === Under Development =====================================================

# --- copy a file with full path ---
sub cp {
	my ($from, $to, %args) = @_;
}

1;

=head1 NAME

iTools::FileSystem - filesystem utilities

=head1 SYNOPSIS

 use iTools::FileSystem qw( ls );

 my $dirlist = ls('/usr/local/bin', '-r', '.*pl$');

=head1 DESCRIPTION

iTools::FileSystem provides utilities that extend Perl's core set of tools for common operations.

=head1 EXPORTS

=head2 ls(PATH, [FLAGS])

Generate a flat hash of files and/or directries with attributes.
FLAGS is a string containing zero or more of th following characters:

 r - recursive
 f - include files
 d - include directories

If 'f' or 'd' are not specifed, they re both assumed.

Returns a hash or hashref with the following:

 FILENAME => {
 	name => FILENAME
	type => 'dir', 'link' or 'file'
  filestat() hash (see below)
 } [...]
 
=head2 filestat(FILENAME)

Returns the results of stat() as a hash/ref.

Fields: dev inode mode numlink uid gid rdev size atime mtime ctime blocksize blocks

=head2 normpath(FILE|DIR)

Returns a normalized path by resolving relative references.

=head2 rmrecursive(FILE|DIR)

VERY DANGEROUS!
Siletly unlinks all files, recursively if necessary.

=head1 NOTES

All of the code in this package has been written to be reasonably compact.
This makes it easier to paste the code into your own scripts if you don't
want to create a dependancy to having this module installed.


=head1 REPORTING BUGS

Report bugs in the Bug Tracker at iTools' SourceForge project page:
L<http://sourceforge.net/projects/itools/>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2026 by Ingmar Ellenberger.

Distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 DEPENDENCIES

Exporter(3pm), Symbol(3pm), strict(3pm) and warnings(3pm) (stock Perl);

=head1 SEE ALSO

iTools::Message(3)

=cut
