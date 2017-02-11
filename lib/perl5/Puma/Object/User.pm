package Puma::Object::User;
use base Puma::Object::Session;

# --- test whether this user is known ---
sub isKnown {
	my $self = shift;
	$self->expandKnown;

	# --- fail if all fields do not exist ---
	return 0 unless
		exists $self->{FullName}  && $self->{FullName}  &&
		exists $self->{FirstName} && $self->{FirstName} &&
		exists $self->{LastName}  && $self->{LastName}  &&
		exists $self->{EMail}     && $self->{EMail}     &&
		exists $self->{Login}     && $self->{Login};

	# --- everything's OK ---
	return 1;
}

# --- expand known fields to fill unknown fields ---
sub expandKnown {
	my $self = shift;

	# --- if we have a FullName, split it into first and last names ---
	if (exists $self->{FullName} && defined $self->{FullName}) {
		$self->{FirstName} = ($self->{FullName} =~ /^(\S*)\s/)[0] || ''
			unless defined $self->{FirstName};
		$self->{LastName} = ($self->{FullName} =~ /\s(\S*)$/)[0] || ''
			unless defined $self->{LastName};
	}

	# --- extract the Login name from the EMail address ---
	if (exists $self->{EMail} && defined $self->{EMail}) {
		$self->{Login} = ($self->{EMail} =~ /^([^@]*)/)[0] || ''
			unless defined $self->{Login};
	}
}

1;


=copyright

Puma - Perl Universal Markup
Copyright (c) 2001, 2002 by Ingmar Ellenberger.

Distributed under The Artistic License.  For the text of this license,
see http://puma.site42.com/license.psp or read the file LICENSE in the
root of the distribution.

=description

	The Stateful User Object

	This package is an extension of the Session object and provides a number
   of methods for user management and verification.

	To implement this object, an entry similar to the following must be added to
   the config.xml:

	<puma>
		<serverpages ... >
			<cookie name="Global30d" expires="+30d"/>
			<session Context="user" Location="state" UseCookie="Global30d"
				module="Puma::ServerPages::User" prefix="user"/>
			...
		</serverpages>
		...
	</puma>

	This example shows a user object (named $user) that maintains state for 30
   days from the last access.

=cut


=Known Users ================================================================

	A known user whose full name and e-mail address are stored in this
   object.

	The FullName and EMail fields are required.
	If FirstName, LastName and Login are not given, an attempt to set these
   values will be made by the expandKnown() method.

=cut


