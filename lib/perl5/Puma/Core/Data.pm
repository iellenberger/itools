package Puma::Core::Data;

use Data::Dumper; $Data::Dumper::Indent = 1; # for debugging only

use strict;
use warnings;

#! TODO: this doesn't belong in ::Core - move it

# === Constructor ===========================================================
sub new {
	my $this = shift;
	my $self = bless {}, ref $this || $this;
	$self->arg(@_);
	return $self;
}

sub arg {
	my ($self, %args) = @_;
	while (my ($key, $value) = each %args) {
		lc $key eq 'config' && $self->config($value);
		lc $key eq 'server' && $self->server($value);
	}
}

sub config { defined $_[1] ? $_[0]->{_config} = $_[1] : $_[0]->{_config} }
sub server { defined $_[1] ? $_[0]->{_server} = $_[1] : $_[0]->{_server} }

sub fetch {
	my $self = shift;
	$self = $self->new() unless ref $self;
	$self->arg(@_);

	print Dumper($self);
}

sub store {
	my $self = shift;
	$self = $self->new() unless ref $self;
	$self->arg(@_);

	print Dumper($self);
}

1;
