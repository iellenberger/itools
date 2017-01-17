package Puma::Object::Application;

sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref($this) || $this;
	@{$self}{keys %args} = values %args;
	return $self;
}
sub getValue { $_[0]->{$_[1]}; }
sub setValue {
	my ($self, %args) = @_;
	@{$self}{keys %args} = values %args;
}



1;

=head1 NAME

Puma::Core::Application - an abstract base class for Puma applications

=head1 SYNOPSIS

 use base Puma::Core::Application;

=head1 DESCRIPTION

An abstract class used for rendering the contents of non-selfending tags.

=head1 METHODS

=head2 new( Server => $server )

=head2 getValue( key )

=head2 setValue( key => 'value' )

=cut
