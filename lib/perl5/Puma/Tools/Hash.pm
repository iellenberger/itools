package Puma::Tools::Hash;
use base Exporter;

@EXPORT_OK = qw( slice merge );

use strict;
use warnings;

# === Hash Slicing ==========================================================
sub slice {
	my $slice; $slice = shift if ref $_[1] eq 'HASH';
	my ($hash, @keys) = @_;
	if (@keys) {
		foreach my $key (@keys) { $slice->{$key} = $hash->{$key} if exists $hash->{$key} }
	} else {
		while (my ($key, $value) = each %$hash) { $slice->{$key} = $value }
	}
	return $slice;
}

# === Hash Merging ==========================================================
# --- overlay one hash (old) on another (new) ---
sub merge {
	my ($mergee, @mergers) = @_;

	# --- validate input params ---
	foreach my $hash (@_) {
		die "Puma::Tools::Hash merge() requires all parameters to be hash references\n"
			unless $hash && ref $hash eq 'HASH';
	}
	return $mergee unless @mergers; # only 1 hash given

	# --- loop through all the hashes merging them one after another ---
	while (my $merger = shift @mergers) {

		# --- push each key on the new hash ---
		while (my ($key, $value) = each %{$merger}) {

			if (ref $mergee->{$key} eq 'HASH') {
				# --- merge 2 matching hashes ---
				merge($mergee->{$key}, $value)
					if ref $value eq 'HASH';
			} else {
				# --- straight replacement ---
				$mergee->{$key} = $value;
	}	}	}

	return $mergee;
}

1;

=head1 NAME

Puma::Tools::Hash - utilities for working with hashes

=head1 SYNOPSIS

   use Puma::Tools::Hash qw( slice );

   my $slice = slice($hash, qw[ key1 key2 ]);
   my $merge = merge($hash1, $hash2);

=head1 DESCRIPTION

=head1 EXPORTED SUBROUTINES

=over 4

=item B<slice>([HASH,] HASH, KEY [, KEY ...])

=item B<merge>(HASH, HASH [, HASH ...])

=back

=head1 EXAMPLES

=head1 TODO

=head1 KNOWN ISSUES AND BUGS

=head1 REPORTING BUGS

Report bugs in the Bug Tracker at iTools' SourceForge project page:
L<http://sourceforge.net/projects/itools/>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2005 by Ingmar Ellenberger.

Distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 DEPENDENCIES

strict(3pm), warnings(3pm) and Exporter(3pm) (stock Perl);

=head1 SEE ALSO

=cut
