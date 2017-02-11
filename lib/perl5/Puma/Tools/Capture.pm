package Puma::Tools::Capture;
use base Exporter;

use Symbol;

@EXPORT_OK = qw( capture );

use strict;
use warnings;

# === Constructor ===========================================================
sub new {
	# --- tie a handle and call it self ---
	my ($this, $handle) = (shift, gensym);
	my $self = tie *{$handle}, ref($this) || $this;

	# --- store handle and return ---
	$self->handle($handle);
	return $self;
}

# === Accessors =============================================================
sub handle { defined $_[1] ? $_[0]->{_handle} = $_[1] : $_[0]->{_handle} }
sub buffer { defined $_[1] ? $_[0]->{_buffer} = $_[1] : $_[0]->{_buffer} }

# === Capturing =============================================================
# --- start and end a capture ---
sub startCapture {
	my $self = shift;
	$self->{_oldfh} = select($self->handle);
	return $self->handle;
}
sub endCapture {
	my $self = shift;
	if ($self->{_oldfh}) { select $self->{_oldfh} }
	else                 { select STDIN }
	return $self->flush();
}

# --- standalone capture method ---
#sub capture($&) {
#	my ($self, $code) = @_;
#	$self->startCapture;
#	$code->();
#	return $self->endCapture;
#}

# --- standalone capture method ---
sub capture(&) {
	my $code = shift;
	my $self = new Puma::Tools::Capture;
	$self->startCapture;
	$code->();
	return $self->endCapture;
}

# === Buffer Management =====================================================
# --- flush the buffer, return flushed contents ---
sub flush {
	my $self = shift;
	my $buffer = $self->buffer;
	$self->buffer('');
	return $buffer;
}
# --- append content to buffer ---
sub append {
	my $self = shift;
	my $buffer = $self->buffer;
	#! TODO: there has to be a more efficient way!
	while (my $arg = shift) { $buffer .= $arg if defined $arg; }
	return $self->buffer($buffer);
}

# === Handle Tie ============================================================
# --- tie and die ---
sub TIEHANDLE { bless {}, ref($_[0]) || $_[0] }
sub CLOSE {}
# === implemented like a pipe ===
# --- write ---
sub PRINT  { shift->append(@_) }
sub PRINTF { shift->append(sprintf shift, @_) }
sub WRITE  { $_[0]->append(defined $_[2] ? substr($_[1], 0, $_[2]) : $_[1]) }
# --- read ---
#! TODO: implement methods below properly
sub READ { $_[0]->flush } #! PARAMS: this, n/a, len, offset
sub READLINE { $_[0]->flush }
sub GETC { $_[0]->flush }

1;

=head1 NAME

Puma::Tools::Capture - 

=head1 SYNOPSIS


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
