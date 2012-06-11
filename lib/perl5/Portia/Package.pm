package Portia::Package;
use base qw( iTools::Core::Accessor HashRef::Maskable );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging only
use HashRef::NoCase qw( nchash );
#use iTools::System qw( die );
#use Portia::Sources;
use Portia::Version;
#use Switch;

use strict;
use warnings;

# === Class Variables =======================================================
# --- persistant instances of objects ---
our $INSTANCES;

# === Constructor and Construtor-like Methods ===============================
# --- new, blank object ---
sub new {
	my ($self, $args) = (shift->mhash, nchash @_);

	# --- package name required ---
	my $name = $args->{name} || $args->{'package'};
	die "attempt to instantiate Portia::Package without giving a package name\n"
		unless $name;

	# --- use existing instance if one exists ---
	$self = $INSTANCES->{$name} if exists $INSTANCES->{$name};
	$self->name($name);
	$INSTANCES->{$name} = $self;

	# --- load versions if a repo was specified ---
	$self->loadVersions($args->{repo})
		if $args->{repo};

	return $self;
}
# --- alias for new ---
sub load {
	my $self = _self(shift, @_);
	my $args = nchash @_;

	# --- load versions if a repo was specified ---
	$self->loadVersions($args->{repo})
		if $args->{repo};

	return $self;
}
# --- guarantee an object by hook or by crook ---
sub _self {
	ref $_[0] && return $_[0];               # we have an object
	defined $_[0] && return shift->new(@_);  # we have a package name
	return __PACKAGE__->new(@_);             # we have nothing
}

# === Accessors =============================================================
sub pname { shift->_var(_name => @_) }
# --- alias for pname ---
sub name  { shift->pname(@_) }

# --- read only accessors ---
sub category  { (shift->pname =~ m|^([^/]*)|)[0] }
sub shortname { (shift->pname =~ m|([^/]*)$|)[0] }

# --- object shortcuts ---
sub sources    { load Portia::Sources }

# === Version Management ====================================================
sub loadVersions {
	my ($self, $repo) = @_;

	# --- load all version of this package fir the given repo ---
	my @versions = loadAll Portia::Version(
		Repo    => $repo,
		Package => $self->name,
	);

	# --- store versions in self ---
	foreach my $version (@versions) {
		my $vname = $version->name;
		$self->{"$repo/$vname"} = $version;
	}
}

sub find {
	my ($package, $args) = (shift, nchash @_);

	# --- generate the query regex ---
	my $query = $args->{query} || '';
	$query = qr/$query/ unless ref $query eq "Regexp";

	# --- default all other args ---
	my $depth = $args->{depth} || 0;
	my $best  = $args->{best}  || 0;
	my @tags  = @{$args->{tags} || []};

	my @versions;

	# --- search packages ---
	foreach my $pname (sort keys %$INSTANCES) {
		my $package = $INSTANCES->{$pname};

		my @pkgvers;

		foreach my $version (values %$package) {
			# --- query depth 0: search name ---
			my $fullname = $version->rname .":". $version->pname ."-". $version->vname;
			if ($fullname =~ $query) {
				$version->best(0);  # set the 'best' string
				push @pkgvers, $version;
				next;
			}
			next unless $depth > 0;

			# --- query depth 1: search descrption ---
			next unless defined $version->{DESCRIPTION};
			if ($version->{DESCRIPTION} =~ $query) {
				$version->best(1);  # set the 'best' string
				push @pkgvers, $version;
				next;
			}
			next unless $depth > 1;

			# --- query depth 3: search long descrption ---
			next unless defined $version->{LONGDESC};
			if ($version->{LONGDESC} =~ $query) {
				$version->best(2);  # set the 'best' string
				push @pkgvers, $version;
				next;
			}
		}

		# --- match tags ---
		@pkgvers = grep { $_->hasTag(@tags) } @pkgvers;

		# --- no match found in this package ---
		next unless @pkgvers;

		# --- sort by best version ---
		@pkgvers = sort { $b->best cmp $a->best } @pkgvers;

		# --- return best version if so requested ---
		if ($best) { push @versions, shift @pkgvers }
		# --- otherwise return all matches ---
		else       { push @versions, @pkgvers }
	}

	# --- return the results ---
	return grep { defined } @versions;
}

1;

__END__

# === Accessors =============================================================
sub versions {
	my $self = shift;
	return keys %$self;
}

# === Public Methods ========================================================

# --- check if the package matches a given set of conditions ---
sub matches {
	my ($self, %params) = @_;
#print Dumper($self);

	# --- we're doing and 'and' match, so return if a condition fails ---
	while (my ($key, $value) = each %params) {
#print "Package::matches($key, $value)\n";

		# --- make sure the value is a regex ---
		$value = qr/$value/ unless ref $value eq "Regexp";

		switch (lc $key) {

			# --- match the name of a package ---
			case 'name' {
				return unless $self->name =~ $value;
			}

#			# --- query repo's tags ---
#			case 'tags' {
#				foreach my $query (ref $value ? @$value : $value) {
#					return unless match($query, $self->{tags});
#				}
#			}
#			# --- query all other keys for the repo ---
#			else {
#				return unless exists $self->{$key} && defined $self->{$key};
#				return unless match($value, $self->{$key});
#			}
		}
	}

	# --- if we got here, we have a match ---
	return $self;
}
