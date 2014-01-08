package Portia::Version;
use base qw( iTools::Core::Accessor HashRef::Maskable );

use feature qw( switch );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging only
use Cwd qw( abs_path );
use HashRef::NoCase qw( nchash );
use iTools::System qw( nofatal mkdir pushdir popdir system );
use Portia::Sources;
use Portia::Tools qw( match source );
use Storable qw( store retrieve );

use strict;
use warnings;

# === Constructor and Construtor-like Methods ===============================
# --- new, blank object ---
sub new {
	my ($self, %args) = (shift->mhash, @_);

   # --- parse incoming parameters ---
	while (my ($key, $value) = each %args) {
		given (lc $key) {
			#! TODO: make these required
			when (/^repo/)         { $self->rname($value) }   
			when (/^(?:pack|pkg)/) { $self->pname($value) }   
			when (/^(?:name|ver)/) { $self->vname($value) }   
			when (/^file/)         { $self->file($value) }   
			when (/^tag/)          { $self->tags(@$value) }   
			default                { $self->{$key} = $value }
		}
	}

	return $self;
}

# === Accessors =============================================================
# --- repo, package, and version name ---
sub rname { shift->_var(repo => @_) }
sub pname { shift->_var('package' => @_) }
sub vname { shift->_var(name => @_) }
# --- alias for vname ---
sub name  { shift->vname(@_) }
# --- filename ---
sub file {
	my $self = shift;
	return $self->_var(file => abs_path(@_)) if @_;
	return $self->_var('file');
}

# --- version tags ---
sub tags { shift->_varArray(tags => @_) }

# --- object shortcuts ---
sub sources { load Portia::Sources }
sub repo    { sources->{shift->rname} }
sub pkg     { load Portia::Package(shift->pname) }

# --- source repo/package root dir ---
sub root { $_[0]->repo->root .'/packages/'. $_[0]->pname }

# --- generate and/or return the 'best' value or tag ---
sub besttag { shift->_varDefault('zzzzz', _besttag => @_) }
sub best {
	my $self = shift;

	# ---- get the best value ---
	my $best = $self->_varDefault(99999, _best => @_);

	# --- this is a get: return the 'best' value ---
	return defined $best ? $best : 99999 unless @_;

	# --- generate the 'best' tag ---
	my $spri = 9 - shift;                               # search priority (usually depth)
	my $rpri = 999 - ($self->repo->{priority} || 999);  # the repo priority
	$self->besttag(sprintf "%d %-30s %03d", $spri, $self->{LONGVERSION}, $rpri);

	# --- return the best value ---
	return $best;
}

sub hasTag {
	my ($self, @tags) = @_;

	return 1 unless @tags;

	foreach my $tag (@tags) {
		return 1 if match $tag, $self->tags;
	}
	return 0;
}

# === Load the .pbuild File =================================================
# --- load all versions for a given repo/package ---
sub loadAll {
	my ($class, $args) = (shift, nchash @_);
	my $rname = $args->{repo};
	my $pname = $args->{'package'} || $args->{pkg};

	# --- find root dir and make sure it exists ---
	my $root = sources->{$rname}->root ."/packages/$pname";
	return unless -d $root;
	pushdir $root;

	# --- stat package's .store and *.pbuild files ---
	# note: we're really only looking for timestamps here
	my ($files, $pbuildmtime) = ({}, 0);
	opendir PKG, ".";
	foreach my $file (readdir PKG) {
		# --- ignore files we don't care about ---
		next unless $file =~ /^(?:\.store|.*?.pbuild)$/;
		# --- suck in fields from stat() to a convenient hashref ---
		@{$files->{$file}}{qw(dev inode mode numlink uid gid rdev size atime mtime ctime blocksize blocks)}
			= stat $file;
		# --- store the epoch time of the most recent *.pbuild file ---
		$pbuildmtime = $files->{$file}->{mtime}
			if $file =~ /.*\.pbuild$/ && $pbuildmtime < $files->{$file}->{mtime};
	}
	closedir PKG;

	my $versions = [];
	# --- if the .store file is out of date, generate a new one ---
	if (!$files->{'.store'} || $files->{'.store'}->{mtime} < $pbuildmtime) {

		# --- source each file and suck in a hash of vars ---
		foreach my $file (keys %$files) {
			next unless $file =~ /.*\.pbuild$/;
			my $vname = ($file =~ /^$pname-(.*?).pbuild$/)[0];

			# --- load the version/pbuild ---
			push @$versions, load Portia::Version(
				File     => $file,
				Repo     => $rname,
				Package  => $pname,
				Version  => $vname,
			);
		}

		# --- save a new .store file ---
		store $versions, '.store' if -w '.';
	}
	# --- the .store file is current, so use it ---
	else {
		$versions = retrieve '.store';
	}
	popdir;

	return wantarray ? @$versions : $versions;
}

# --- load a single version/pbuild ---
sub load {
	my ($class, $args) = (shift, nchash @_);

	# === Paramater Processing ===
	# --- merge 'package' and 'pkg' args ---
	$args->{pkg} ||= $args->{'package'} || '';
	delete $args->{'package'};

	# --- split category and package ---
	if ($args->{pkg} =~ m|^([^/]*)/([^/]*)$|) {
		$args->{category} ||= $1;
		$args->{pkg} = $2;
	}

	# === Sourcing the PBuild ====
	# --- source the file ---
	my $vhash = source { import => 0 }, $args->{file};

	# --- default some values ---
	my $cname = $vhash->{CATEGORY} || $args->{category};
	my $pname = $vhash->{PACKAGE}  || $args->{pkg};
	my $vname = ($args->{file} =~ /^$pname-(.*?).pbuild$/)[0] || $vhash->{VERSION} || $args->{version};

	# --- set some export defaults ---
	$vhash->{CATEGORY} ||= $cname;
	$vhash->{PACKAGE}  ||= $pname;
	$vhash->{VERSION}  ||= $vname;
	$vhash->{TAGS}     ||= 'stable';

	# --- if REVISION is blank, make sure it's undef ---
	delete $vhash->{REVISION}
		if !defined $vhash->{REVISION} || $vhash->{REVISION} =~ /^\s*$/;

	# --- generate the sortable version ---
	my $rev = $vhash->{REVISION};
	my $fullversion = $vhash->{VERSION} . (defined $rev ? "-$rev" : '');
	$vhash->{LONGVERSION} = longVersion($fullversion);

	# --- split tags into an array ---
	my @tags = map { lc } grep { $_ } split /\s+/, $vhash->{TAGS} || '';

	# === Cleanup and Object Creation ===
	# --- clean up stuff we don't want to store ---
	foreach my $key (keys %$vhash) {
		# --- only keep vars that are all-upper and underscores ---
		delete $vhash->{$key} unless $key =~ /^[A-Z_]*$/;
	}

	# --- create a new version object map its values ---
	my $version = new Portia::Version(
		Repo    => $args->{repo},
		Package => "$cname/$pname",
		Version => $vname,
		Tags    => [ @tags ],
		File    => $args->{file},
	);
	map { $version->{$_} = $vhash->{$_} } keys %$vhash;

	return $version;
}

sub longVersion {
	my $version = shift;

	# --- first split along dashes ---
	my @dashes;
	foreach my $dash (split '-', $version) {
		
		# --- no dots? treat as string ---
		unless ($dash =~ /\./) {
			# --- four-char, zero justify any digits ---
			$dash =~ s/(\d+)/sprintf("%04d",$1)/ge;
			push @dashes, sprintf "%-16s", $dash;
			next;
		}

		# --- split along dots and treat as a six part version string ---
		my @dots = (split /\./, $dash);
		for (my $ii = 0; $ii < 6; $ii++) {
			$dots[$ii] ||= 0;
			$dots[$ii] =~ s/(\d+)/sprintf("%04d",$1)/ge;
		}

		# --- rejoin dotted parts ---
		push @dashes, join('.', @dots);
	}

	# --- reconstitute the parts and return ---
	return join '-', @dashes;
}

=foo

# --- convert a version string to a sortable zero-justified, six-part value ---
sub sixDots {
	my $version = (shift || 0);
	my @parts = split /\./, $version;

	# --- treat parts as a six-dot version string ---
	for (my $ii = 0; $ii < 6; $ii++) {
		# --- set all digits to fourZeros ---
		$parts[$ii] = fourZeros($parts[$ii] ||= 0);
	}
	# --- return the joined parts ---
	return join '.', @parts;
};

# --- four-char, zero justify digits ---
sub fourZeros {
	my $string = shift;
	$string =~ s/(\d+)/sprintf("%04d",$1)/ge;
	return $string;
}

=cut

1;
