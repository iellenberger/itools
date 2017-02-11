package Puma::Cookie::Session;
use base Puma::Object::Serial;

use Storable qw( dclone );

use strict;
use warnings;

# === Constructor ===========================================================
# --- empty constructor for convenience ---
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref($this) || $this;

	# --- get params ---
	while (my ($key, $value) = each %args) {
		lc $key eq 'location' && $self->location($value);
		lc $key eq 'cookie'   && $self->cookie($value);
		lc $key eq 'context'  && $self->context($value);
		lc $key eq 'server'   && $self->server($value);
	}

	# --- get the cookie's UID ---
	$self->uid($self->server->getCookie($self->cookie)->value)
		if defined $self->server && defined $self->cookie;

	# --- unserialize the object if it exists and return it ---
	return $self->load;
}

# === Accessors =============================================================
# --- fields hidden from serialization ---
sub hidden { defined $_[1] ? $_[0]->{_hide} = $_[1] : $_[0]->{_hide} }
sub cookie   { defined $_[1] ? $_[0]->{_hide}->{cookie}   = $_[1] : $_[0]->{_hide}->{cookie} }
sub context  { defined $_[1] ? $_[0]->{_hide}->{context}  = $_[1] : $_[0]->{_hide}->{context} }
sub location { defined $_[1] ? $_[0]->{_hide}->{location} = $_[1] : $_[0]->{_hide}->{location} }
sub server   { defined $_[1] ? $_[0]->{_hide}->{server}   = $_[1] : $_[0]->{_hide}->{server} }
sub uid      { defined $_[1] ? $_[0]->{_hide}->{uid}      = $_[1] : $_[0]->{_hide}->{uid} }

# --- generate the filename for the serialized object ---
sub filename {
	my $self = shift;
	my $filename = $self->location .'/'. $self->context .'.'. $self->uid;
	$filename =~ s|/+|/|g;  # trim multiple '/'s
	return $filename;
}

sub load {
	my $self = shift;
	my $file = shift || $self->filename;
	if (-e $file) {
		my $hidden = $self->hidden;        # store hidden fields
		$self = $self->unserialize($file); # reload self from file
		$self->hidden($hidden);            # restore hidden fields
	}
	return $self;
}

sub save {
	my $self = shift;
	my $file = shift || $self->filename;
	$self->serialize($file);
}

# === Method Extended from Puma::Object::Serial =============================
# --- make a clone of self and remove all data we don't want to serialize ---
sub serial {
	my $self = dclone(shift);
	delete $self->{_hide};
	return $self;
}

1;
