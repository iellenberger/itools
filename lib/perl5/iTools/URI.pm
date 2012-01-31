package iTools::URI;
use base qw( iTools::Core::Accessor );
$VERSION = 0.1;

use Data::Dumper; $Data::Dumper::Indent=0; # for debugging

use strict;
use warnings;

# === Constructor/Destructor ================================================
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref $this || $this;

	# --- parse incoming parameters ---
	while (my ($key, $value) = each %args) {
		lc $key eq 'url' && $self->url($value);
		lc $key eq 'uri' && $self->uri($value);
	}

	return $self;
}

# === Accessors =============================================================
# --- simple URI components ---
sub scheme   { shift->_var(scheme   => @_) }
sub user     { shift->_var(user     => @_) }
sub password { shift->_var(password => @_) }
sub host     { shift->_var(host     => @_) }
sub fragment { shift->_var(fragment => @_) }
sub port     { shift->_var(port     => @_) }
sub path     { shift->_var(path     => @_) }

# === URI Managment =========================================================
sub url { shift->uri(@_) }
sub uri {
	my $self = shift;

	# === Accessor GET ===
	unless (@_) {

		# --- fetch components for convenience ---
		my ($scheme, $auth, $path, $query, $frag) = 
			($self->scheme, $self->authority, $self->path, $self->query, $self->fragment);

		# --- build the authority ---
		my $uri = 
			($scheme ? $scheme .':' : '') .
			($auth ? '//'. $auth : '') .
			($path || '') .
			($query ? '?'. $query : '') .
			($frag ? '#'. $frag : '');

		# --- undef if blank and return ---
		$uri = undef if $uri eq '';
		return $uri;
	}

	# === Accessor RESET ===
	if (! defined $_[0]) {
		$self->scheme(undef);
		$self->authority(undef);
		$self->path(undef);
		$self->query(undef);
		$self->fragment(undef);
		return undef;
	}

	# === Accessor SET ===
	# --- grab the incoming URI ---
	my $uri = shift;
	$uri =~ s/\\/\//g;

	# --- regex for parsing the URI (stolen from URI.pm) ---
	my $reuri = qr{
		(?:([^:/?#]+):)?  # 1) scheme:    before [:/?#]:
		(?://([^/?#]*))?  # 2) authority: between \g// and [/?#]
		([^?#]*)          # 3) path:      between \g and [?#]
		(?:\?([^#]*))?    # 4) query:     between \g? and #
		(?:\#(.*))?       # 5) fragment:  after \g#
	}x;

	# --- parse the uri and save the bits ---
	$uri =~ /$reuri/s;
	$self->scheme($1);
	$self->authority($2);
	$self->path($3);
	$self->query($4);
	$self->fragment($5);

	# --- return the reformed uri ---
	return $self->uri;
}

# --- the authority record ---
sub authority {
	my $self = shift;

	# === Accessor GET ===
	unless (@_) {

		# --- fetch components for convenience ---
		my ($user, $pass, $host, $port) =
			($self->user, $self->password, $self->host, $self->port);

		# --- build the authority ---
		my $auth = 
			($user || $pass
				? ($user || '') . ($pass ? ':'. $pass : '') .'@'
				: ''
			) .
			($host || '') .
			($port ? ':'. $port : '') ;

		# --- undef if blank and return ---
		$auth = undef if $auth eq '';
		return $auth;
	}

	# === Accessor RESET ===
	if (!defined $_[0]) {
		$self->user(undef);
		$self->password(undef);
		$self->host(undef);
		$self->port(undef);
		return undef;
	}

	# === Accessor SET ===
	# --- grab the incoming authority ---
	my $auth = shift;

	# --- regex for parsing auth ---
	my $reauth = qr{
		(?:            # user/password:
			([^:@]+)?      # 1) user: before [^:@]@
			(?::([^@]+))?  # 2) password: between \g: and @
		@)?
		([^:]*)           # 3) host: between \g and :
		(?::(.*))?        # 4) port: after \g:
	}x;

	# --- parse the authority and save the bits ---
	$auth =~ /$reauth/s;
	$self->user($1);
	$self->password($2);
	$self->host($3);
	$self->port($4);

	# --- return the reformed authority ---
	return $self->authority;
}

# --- query management ---
sub queryHash { shift->_var(query => @_) }
sub query {
	my $self = shift;

	# === Accessor GET ===
	unless (@_) {
		my $qhash = $self->queryHash;

		# --- build the query array ---
		my @qarray;
		foreach my $key (sort keys %$qhash) {
			my $value = $qhash->{$key};
			if (!defined $value) {
				push @qarray, $key;                 # stand-alone key
			} elsif (ref $value) {
				foreach my $innerval (@$value) {
					push @qarray, "$key=$innerval";  # multiple values for a key
				}
			} else {
				push @qarray, "$key=$value";        # key/value pair
		}	}

		# --- stringify the query and return ---
		my $query = join '&', @qarray;
		$query = undef if $query eq '';
		return $query;
	}

	# === Accessor RESET ===
	if (!defined $_[0]) {
		$self->queryHash(undef);
		return undef;
	}

	# === Accessor SET ===
	# --- grab the incoming query ---
	my $query = shift;
	my $qhash;

	foreach my $element (split '&', $query) {
		my ($key, $value) = split '=', $element;

		# --- add a new key ---
		unless (exists $qhash->{$key}) {
			$qhash->{$key} = $value;
			next;
		}

		# --- add to an existing key ---
		my $keyarray = $qhash->{$key};
		$keyarray = [ $keyarray ] unless ref $keyarray;
		push @$keyarray, $value;
		$qhash->{$key} = $keyarray;
	}
	# --- save the new hash ---
	$self->queryHash($qhash);

	# --- return the reformed query ---
	return $self->query;
}

1;

=head1 NAME

iTools::URI - a class for managing file locations

=head1 SYNOPSIS

  use iTools::URI;

  my $x = new iTools::URI(URI => 'http://domain.com/');
  $x->port(8000);              # add a port
  $x->host('beta.domain.com'); # change the host
  $x->path('/index.html');     # add a path
  my $uri = $x->uri;           # 'http://beta.domain.com:8000/index.html'

=head1 DESCRIPTION

B<iTools::URI> is is a class used to parse, manipulate and store URI style location strings.

This class uses a simple regular expression to parse a URI into it's individual components.
It will reliably parse all B<RFC 3986> compliant URIs into the following components:

    scheme
    authority
        user
        password
        host
        port
    path
    query
        key [=> value]
        [...]
    fragment


This class does not provide any facility to validate for compliance.
Parsing non-compliant URIs has not been tested and may produce unpredictable results.

The regular expression for parsing the base URI was taken from URI(3pm), available through CPAN.

=head1 CONSTRUCTOR

=over 4

=item new iTools::URI([URI => I<URI>)

Creates and returns a new object for the class.
The object can optionally be seeded with a B<URI>.

=back

=head1 ACCESSORS

=head2 Universal Accessors

An accessor labelled as B<universal> is an accessor that allows you to get, set and unset a value with a single method.
To get a the accessor's value, call the method without parameters.
To set the value, pass a single parameter with the new or changed value.
To unset a value, pass in a single parameter of B<undef>.

For details on B<universal> accessors, see the iTools::Core::Accessor(3pm) man page.

=over 4

=item $obj->B<scheme>([I<VALUE>])

=item $obj->B<user>([I<VALUE>])

=item $obj->B<password>([I<VALUE>])

=item $obj->B<host>([I<VALUE>])

=item $obj->B<port>([I<VALUE>])

=item $obj->B<path>([I<VALUE>])

=item $obj->B<fragment>([I<VALUE>])

All of the methods B<universal> accessors to the URI component of the same name.
They may be used to fetch individual values for a parsed URI or to set/change values for an new or existing URI.

All of these accesors perform no processing beyond storing values.
See the methods below for information on content parsing.

=item $obj->B<uri>([I<URI>])

This method is the primary method for loading I<URI>s.
Is acts as a B<universal> accessor, but does not store I<URI> directly.
Instead, it parses the given B<URI> into its components and uses other accessors to store them.

The I<URI> is broken into the following components: scheme, authority, path, query and fragment.
The authority and query are then subsequently broken down into smaller components by their accessors.

Returns a B<URI> reconstituted from the stored components.

=item $obj->B<authority>([I<AUTHORITY>])

Similar to the uri() method, authority() does not store it's own value directly, but rather uses other accessors to store its component parts.
The B<AUTHORITY> consists of the following parts: user, password, host and port.

Returns a reconstituted B<AUTHORITY> string.

=item $obj->B<query>([I<QUERY>])

The query() method parses I<QUERY> into a series of key/value pairs and stores it as a hash.
The hash is composed as follows:

    Incoming QUERY: key1&key2=val21&key3=val31&key3=val32
    Generated hash:
        key1 => undef,
        key2 => val2,
        key3 => [ val31, val32 ]

Returns a reconstituted B<QUERY> string, ordered by key.

=item $obj->B<queryHash>([HASH])

A B<universal> accessor for the hash generated and used by the query() method.

=back

=head1 TODO

=over 4

=item B<Escape Sequence Encoding and Decoding>

Consider the use of an external class (it may be meeded more universally).

=back

=head1 KNOWN ISSUES AND BUGS

=over 4

=item B<Passwords in The URI>

RFC 3986 deprecates the use pf passwords in the URI string.
For backwards compatibilty, parsing the password as a separate field has been included in this class.
This functionality may be deprecated in the future.

=back

=head1 REPORTING BUGS

Report bugs in the Bug Tracker at iTools' SourceForge project page:
L<http://sourceforge.net/projects/itools/>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2011, Ingmar Ellenberger
and distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the Puma distribution.

Some parts copyright (c) 1995-2003, Gisle Aas; 1995, Martijn Koster.
Distributed under The Artistic License.
L<http://search.cpan.org/dist/URI/URI.pm>

=head1 DEPENDENCIES

strict(3pm) and warnings(3pm),
iTools::Core::Accessor(3pm)

=head1 SEE ALSO

iTools::Core::Accessor(3pm),
URI(3pm)

=cut
