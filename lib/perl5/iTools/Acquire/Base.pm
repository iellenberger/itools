package iTools::Acquire::Base;
use base qw( iTools::Core::Accessor );
$VERSION = "0.01";

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::URI;

use strict;
use warnings;

# === Constructor/Destructor ================================================
sub new {
	my ($this, $uri, %args) = @_;
	my $self = bless {}, ref $this || $this;

	# --- save URI and args to self ---
	$self->uri($uri);
	map { $self->{lc $_} = $args{$_} } keys %args;

	return $self;
}

# === Accessors =============================================================
sub uri     { shift->_var(uri     => @_) }
sub content { shift->_var(content => @_) }

# === Stubs =================================================================
sub fetch {}

# === Messages ==============================================================
sub message {
	my $self = shift;
	my $message = $self->{_message};
	if (@_) {
		$message = '' unless defined $message;
		$message .= join ' ', @_;
	}
	return $self->{_message} = $message;
}

1;

=head1 NAME

iTools::Acquire::Base - base module for iTools::Acquire loaders

=head1 SYNOPSIS

 package My::Loader;
 use base "iTools::Acquire::Base";

 sub fetch {
    my ($self, $uri) = @_;
    $uri = $self->uri unless defined $uri;

    $self->content(
       # fetch content here
    );

    if ($self->content) { $self->message("Got it!") }
    else                { $self->message("Something went wrong") }

    return $self->content;
 }

=head1 DESCRIPTION

B<iTools::Acquire::Base> is the base class for B<iTools::Acquire> loaders.

=head1 METHODS

B<Required Method Overrides>

=over 2

The following methods must be overriden in all subclasses:

=over 4

=item B<fetch>([I<URI>])

Returns fetched content.
A B<iTools::URI> object will be passed to either the constructor or or this method.
A blank or undefined B<URI> should return C<undef> and an error message.

See L<SYNOPSIS> for a code example.

=back

=back

B<Constructor>

=over 2

=over 4

=item B<new>([I<PATH>], [I<ARGS>])

I<PATH> is an object of type B<iTools::URI> and is saved via the B<uri()> accessor.
I<ARGS> is a hash of values that the constructor stores as values in C<$self>.

=back

=back

B<Accessors>

=over 2

=over 4

=item B<content>([I<CONTENT>])

The last fetched content.

=item B<message>([I<MESSAGE>])

Used to fetch/store human readable error/warning/information messages.

=item B<uri>([I<URI>])

A B<iTools::URI> object containg the path to the desired content.

=back

=back

=head1 TODO, KNOWN ISSUES AND BUGS

None.

=head1 REPORTING BUGS

Report bugs in the Bug Tracker at Puma's SourceForge project page:
L<http://sourceforge.net/projects/puma/>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2011 by Ingmar Ellenberger.

Distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the Puma distribution.

=head1 DEPENDENCIES

strict(3pm) and warnings(3pm);
iTools::Core::Accessor(3pm)

=head1 SEE ALSO

iTools::Acquire(3pm),
iTools::URI(3pm)

=cut
