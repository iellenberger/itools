package Puma::Core::Server;
use base qw( iTools::Core::Accessor );
our $VERSION = 0.1;

use CGI;
use CGI::Carp 'fatalsToBrowser';
use CGI::Cookie;

use Puma::Core::Config;

use strict;
use warnings;

# === Constructor ===========================================================
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref $this || $this;

   # --- parse incoming parameters ---
	while (my ($key, $value) = each %args) {
		lc $key eq 'puma' && $self->puma($value);
	}

	# --- create the configuration object ---
	my $config = new Puma::Core::Config;
	$self->config($config->getConfig);

	# --- create the CGI object ---
	$self->cgi(new CGI);

	# --- do the cookie thing ---
	my $cookies = $self->config->{cookie};
	if ($cookies) {
		$cookies = [ $cookies ] unless ref($cookies) eq 'ARRAY';
		for (my $ii = 0; $ii < @$cookies; $ii++) {
			$self->bake($cookies->[$ii]);
	}	}

	$self->preloadSessions;

	return $self;
}

# --- constructor helpers ---------------------------------------------------
sub preloadSessions {
	my $self = shift;

	# --- get session data from config XML ---
	my $sessions = $self->config->{session};
	$sessions = [ $sessions ] unless ref($sessions) eq 'ARRAY';

	# --- create the sessions and sttore them ---
	foreach my $session (@$sessions) {
		# --- skip this one if not preload ---
		#! TODO: preload?  can we use a better name?
		next unless exists $session->{preload}; #! TODO: Do we want this to be default?
		next unless $session->{preload} =~ /^(?:t|true|y|yes|1)$/i;

		# --- create a new session object ---
		eval "require $session->{module}";
		my $obj = $session->{module}->new(
			Location => $session->{location},
			Context  => $session->{context},
			Cookie   => $session->{cookie},
			Server   => $self,
		);

		# --- store it in the sessions hash ---
		$self->session($session->{prefix}, $obj);
	}
}

sub preloadApplications {
	my $self = shift;

	my $sessions = $self->config->{session};
	$sessions = [ $sessions ] unless ref($sessions) eq 'ARRAY';

	foreach my $session (@$sessions) {
		next unless exists $session->{preload};
		next unless $session->{preload} =~ /^(?:t|true|y|yes|1)$/i;

		eval "require $session->{module}";
		my $obj = $session->{module}->new(
			Location => $session->{location},
			Context  => $session->{context},
			Cookie   => $session->{cookie},
			Server   => $self,
		);

		$self->session($session->{prefix}, $obj);
	}
}

# === Accessors =============================================================
sub config      { shift->_var(_config => @_) }
sub puma        { shift->_var(_puma => @_) }

sub session     { defined $_[2] ? $_[0]->{_session}->{$_[1]} = $_[2]     : $_[0]->{_session}->{$_[1]} }
sub application { defined $_[2] ? $_[0]->{_application}->{$_[1]} = $_[2] : $_[0]->{_application}->{$_[1]} }
sub app { shift->application(@_) }

# --- accessor for CGI object ---
sub cgi { shift->_var(_cgi => @_) }
# --- get/set page redirection ---
sub redirect { shift->_var(_redirect => @_) }
# --- CGI pass-thru method ---
sub param { return shift->cgi->param(@_) }

# === Page Start and End Code ===============================================
sub getStartCode {
	my $self = shift;

	# --- get the config hash ---
	my $config = $self->config;

	# --- get the definitions for the session objects ---
	my $sessions = $config->{session};
	# --- coerce $sessions into an array if it isn't one already ---
	$sessions = [ $sessions ] unless ref($sessions) eq 'ARRAY';

	my $code = '';
	# --- create the code to load the session objects ---
	foreach my $session (@$sessions) {
		# --- load the session object module ---
		my $sobj = '';

		if ($session->{prefix}) {
			if (my $obj = $self->session($session->{prefix})) {
				$sobj = qq[ my \$$session->{prefix} = \$server->session('$session->{prefix}'); ];
			} else {
				# --- instantiate the session object ---
				$sobj = qq[
					use $session->{module};
					my \$$session->{prefix} = new $session->{module}(
						Location  => "$session->{Location}",
						Context   => "$session->{Context}",
						Cookie    => '$session->{Cookie}',
						Server    => \$server,
					);
					\$server->session('$session->{prefix}' => \$$session->{prefix});
				];
			}
		}

		# --- get rid of extra whitespace ---
		$sobj =~ s/^\s+//g; $sobj =~ s/\s+/ /g;
		$code .= "$sobj\n";
	}

	# --- load libs ---
	$code .= "use lib qw($config->{perl}->{libs});\n" if $config->{perl}->{libs};

	# --- set the global $puma hash ---
	#! BUG: This should be just $server->config
	$code .= "my \$puma = \$server->puma;\n";
	
	# --- set local vars ---
	if ($config->{vars}) {
		$code .= "\n";
		foreach my $key (keys %{$config->{vars}}) {
			$code .= "my \$$key = qq[". $config->{vars}->{$key} .']; ';
		}
	}

	# --- run startcode ---
	$code .= "\n$config->{startscript}\n" if $config->{startscript};

	return $code;
}

sub getEndCode {
	my $self = shift;
	my $config = $self->config;

	my $sessions = $config->{session};
	$sessions = [ $sessions ] unless ref($sessions) eq 'ARRAY';

	my $code = '';
	# --- run endcode ---
	$code .= "\n$config->{endscript}\n" if $config->{endscript};

	# --- close off sessions ---
	foreach my $session (@$sessions) {
		$code .= qq[\$$session->{prefix}->save();\n];
	}

	return $code;
}

# === Miscellanous Bits and Pieces ==========================================
# --- current working directory ---
sub cwd { return ($ENV{PATH_TRANSLATED} =~ m|^(.*/)[^/]+$|)[0]; }

sub header {
	my $self = shift;

	# --- are we doing a redirect? ---
	if ($self->redirect) {
		# --- close off sessions ---
		my $sessions = $self->config->{session};
		$sessions = [ $sessions ] unless ref($sessions) eq 'ARRAY';
		foreach my $session (@$sessions) {
			$self->session("$session->{prefix}")->save();
		}

		# --- tell CGI to redirect if one is in the queue ---
		return $self->cgi->redirect($self->redirect) if $self->redirect;

		# --- add cookies to the header ---
		$self->headerParam('-cookie' => $self->{_baked}) if $self->{_baked};

		# --- return the header ---
		return $self->cgi->header(%{$self->headerParam});
	}

	# --- add cookies to the header ---
	my $params = $self->headerParam('-cookie' => $self->{_baked}) if $self->{_baked};

	# --- return the header ---
	return $self->cgi->header(%$params);
}

# --- generate a hash of CGI parameters ---
sub paramHash {
	my $self = shift;

	# --- preset a few variables ---
	my $cgi = $self->cgi;
	my @keys = $cgi->param;
	my $hash = {};

	# --- loop through each parameter, storing each value in a hash ---
	foreach my $key (@keys) {
		if (@{$cgi->{param}->{$key}} == 1) { $hash->{$key} = $cgi->{param}->{$key}->[0] }
		else                               { $hash->{$key} = $cgi->{param}->{$key} }
	}

	return wantarray ? %$hash : $hash;
}

# --- set/get HTTP header parameters ---
sub headerParam {
	my ($self, %args) = @_;

	# --- set values for header if arguments given ---
	@{$self->{_headerParams}}{keys %args} = values %args if %args;

	# --- return the header parameter hash ---
	return $self->{_headerParams};
}

# === Cookie Handling =======================================================
sub bake {
	my $self = shift;

	my %args = @_ == 1 ? %{$_[0]} : @_;

	my $name    = $args{name};
	my $expires = $args{expires};
	my %cookies = fetch CGI::Cookie;

	my $cookie;
	if (exists $cookies{$name} && defined $cookies{$name}) {
		$cookie = $cookies{$name};
		$cookie->expires($expires) if $expires;
	} else {
		my $value = crypt(time * rand, 'puma');
		$value =~ s/[^0-9A-Za-z]//g;
		my %params = (
			-name  => $name,
	   	-value => $args{value} || $value,
		);
		$params{'-expires'} = $expires if $expires;

		$cookie = new CGI::Cookie(%params);
	}

	$self->{_baked} = [] unless $self->{_baked};
	push @{$self->{_baked}}, $cookie;

	return $cookie;
}

sub getCookie {
	my ($self, $name) = @_;

	return undef unless $name;

	foreach my $cookie (@{$self->{_baked}}) {
		return $cookie if $cookie->name() eq $name;
	}

	return undef;
}

1;

=head1 NAME

Puma::Core::Server - server object for Puma

=head1 SYNOPSIS

  my $server = new Puma::Core::Server;
  print $server->header;
  eval $server->getStartCode . $engine->render . $server->getEndCode;

=head1 DESCRIPTION

This is the 'server' object for Puma.

=head1 METHODS


=over 4

=item B<Constructor>

=over 4

=item B<new Puma::Core::Config>()

The object constructor.

=back

=item B<Accessors>

=over 4

=item $obj->B<cgi>([CGI])

=item $obj->B<config>([CONFIG])

=item $obj->B<session>(NAME [=> OBJECT])

These methods get/set objects and data strictures stored in the B<server> object.

B<cgi>() returns Puma's current CGI object. 
B<config>() returns the page's configuration hash (see B<Puma::Core::Config>).
B<session>(NAME) returns the session object named B<NAME> (see B<Puma::Object::Session>).

All of these objects are automagically set before the content of the page is rendered,
so unless you're intending to do fancy-dancy low-level manipulation of Puma's underbelly,
it's best to leave out the optional 'set' parameter.

=back

=item B<Cookie Manipulation>

=over 4

=item $obj->B<bake>(name => NAME, expires => EXPIRY [,value => VALUE])

This is a cookie creation wrapper for B<CGI::Cookie>.

If the B<NAME>d cookie does not exist, a new one is created.
If the cookie already exists, it is updated with the new B<EXPIRY> and (optionally) B<VALUE>.

B<EXPIRY> can take any of the following forms:

  +30s - 30 seconds from now
  +10m - ten minutes from now
  +1h  - one hour from now
  -1d  - yesterday (i.e. "ASAP!")
  now  - immediately
  +3M  - in three months
  +10y - in ten years time
  Thursday, 25-Apr-1999 00:40:33 GMT
       - at the indicated time & date

If no B<VALUE> is given, a unique hash is generated for the B<VALUE>.

Returns the B<bake>d cookie.

=item $obj->B<getCookie>(NAME)

Returns the B<CGI::Cookie> object by the given B<NAME>.

=back

=item B<CGI (Form) Parameters>

=over 4

=item $obj->B<param>(ARGS)

A direct wrapper of B<CGI>'s B<param> method.

=item $obj->B<paramHash>()

Returns all B<CGI> parameters as a hash (or hashref - see B<perldoc -f wantarray>).

=back

=item B<Headers and Redirects>

=over 4

=item $obj->B<headerParam>(KEY => VALUE [, ...])

This method used to set values in libraries, objects and the Puma script itself for the header that is to be generated later.

=item $obj->B<header>([ARGS])

Generates a HTTP header based on the baked cookies and the values passed to B<headerParam>().
If a B<redirect> URL was set, any open sessions will be saved and a redirect header will be generated.

Returns an HTTP header.

=item $obj->B<redirect>(URL);

Sets a redirect URL.
If no URL is set, or the URL is '', no redirect will take place.

=back

=item B<Puma Processing Bits>

=over 4

=item $obj->B<getStartCode>()

=item $obj->B<getEndCode>()

Generates the code to be eval'ed before and after the Puma page.
Used by B<puma2.cgi>.
Should be of no concern to most people.

=item $obj->B<cwd>()

Returns the current working directory - i.e. the filesystem location of the Puma page being processed.

=back

=back

=head1 CONFIGURATION FILES

Puma::Core::Server uses instantiated an instance of the B<Puma::Core::Config> package to retrieve its configuration information.
In particular, it looks for the following tags:

  <!-- browser session cookie -->
  <cookie name="Global" />
  <session Context="session" Location="/ITOOLS_ROOT/var/state/puma/session"
    Cookie="Global" module="Puma::Object::Session" prefix="session" />

  <!-- user cookie, expires 30 days after last access -->
  <cookie name="Global30d" expires="+30d" />
  <session Context="user" Location="/ITOOLS_ROOT/var/state/puma/user"
    Cookie="Global30d" module="Puma::Object::User" prefix="user" />

For more information on the use of configuration files, see tha manpage for B<Puma::Core::Config>.

=head1 OPTIONS AND PARAMETERS

=head1 RULES OF CONDUCT

=head1 EXAMPLES

=head1 TODO

  - URL option & ORB plugin
  - Object Serialization
    - Deserialize on create using DD/Storable
      - extension matching: .puma .xml .dd .store .freeze
    - Serialize method
      - .dd by default?
      - remove local config before serializing
  - Add constructor option to not load local
  - Add dir accessor -> dir(name => {config})

=head1 KNOWN ISSUES AND BUGS

=head1 REPORTING BUGS

Report bugs in the Bug Tracker at Puma's SourceForge project page:
L<http://sourceforge.net/projects/puma/>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2008 by Ingmar Ellenberger.

Distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the Puma distribution.

Some portions of this manual page copied from Perl's B<CGI> manual page.
B<CGI> is distributed under The Artistic License, copyright (c) 1995-1998, Lincoln D. Stein.

=head1 DEPENDENCIES

Storable(3pm), strict(3pm) and warnings(3pm) (stock Perl);
Puma::Core::Engine(3pm), Puma::Object::Serial(3pm),
iTools::XML::Simple(3pm)

=head1 SEE ALSO

=cut
