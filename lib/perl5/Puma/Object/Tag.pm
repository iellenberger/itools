package Puma::Object::Tag;
use base 'Puma::Object::Base';

use strict;
use warnings;

=TODO

add recursive pre-rendering.  this will solve the forms issue
make on-the-fly body rendering easier.  see Experimental for a start

=cut

# === Class Methods =========================================================
sub objectType { 'Tag' }

# === Constructor ===========================================================
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref $this || $this;

	# --- parse incoming parameters ---
	while (my ($key, $value) = each %args) {
		lc $key eq 'parent' && $self->parent($value);
		lc $key eq 'server' && $self->server($value);
	}

	# --- get server from parent if it wasn't passed in ---
	$self->server($self->parent->server)
		if !$self->server && $self->parent;

	return $self;
}

# === Accessors =============================================================
sub parent { defined $_[1] ? $_[0]->{_parent} = $_[1] : $_[0]->{_parent} }
sub server { defined $_[1] ? $_[0]->{_server} = $_[1] : $_[0]->{_server} }

sub getBody {
	my $self = shift;

	my $args = @_ == 1 ? shift : { @_ };
	my $body = delete $args->{tagBody} || sub {};
	return wantarray ? ($body, %$args) : $body;
}

1;

=head1 NAME

Puma::Object::Tag - an abstract base class for Puma tags

=head1 SYNOPSIS

 use base Puma::Tag;

=head1 DESCRIPTION

An abstract class used for rendering the contents of non-selfending tags.

=head1 METHODS

=head2 render();

The render() method is a stub intended for future extension.
I am of the mind that this is a poorly thought out idea and I may depricate
it soon.

=head2 renderChildren();

This method is designed to render the contents of non-selfending tags.
In the case of Puma, the contents of a given tag are not
included in line as a part of codification.
In order for the content between start and end tags to be rendered, the
method that is called by the tag must call $self->renderChildren();

This method takes no parameters and returns the cumulated value of the child
calls.

=head1 SEE ALSO

Puma/Devel/Form.pm

=head1 COPYRIGHT

Copyright (c) 2001, 2002 by Ingmar Ellenberger.

Distributed under The Artistic License.  For the text of this license,
see http://puma.site42.com/license.psp or read the file LICENSE in the
root of the distribution.

=cut
