package Portia::Sources;
use base qw( iTools::Core::Accessor HashRef::Maskable );

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging only

use HashRef::NoCase qw( nchash );
use iTools::File qw( readfile );
use iTools::Verbosity qw( vprint );
use iTools::YAML;
use Portia::Repository;
use Portia::Tools qw( indent interpolate );

# === Class Variables =======================================================
# --- persistant instance of object ---
our $INSTANCE;

# === Constructor and Construtor-like Methods ===============================
# --- new, blank object ---
sub new {
	my ($self, $args) = (shift->mhash, nchash @_);
	$INSTANCE = $self;

	# --- parse incoming parameters ---
	while (my ($key, $value) = each %$args) {
		lc $key eq 'root' && $self->root($value);
	}

	# --- load the sources files ---
	$self->loadSources(Repo => $args->{repo});

	return $self;
}
# --- return current instance or new object ---
sub load { $INSTANCE || shift->new(@_) }
# --- make sure we have an object by hook or by crook ---
sub _self {
	ref $_[0] && return $_[0];                # we have an object
	defined $_[0] && return shift->load(@_);  # we have a package name
	return __PACKAGE__->load(@_);             # we have nothing
}

# === Accessors =============================================================
# --- root dir of all sources (read-only) ---
sub root { _self(shift)->_varDefault("$ENV{PORTIA_LIB}/sources", _root => @_) }

# === General Methods =======================================================
# --- show sources config ---
sub dumpConfig {
	my $self = _self(shift, @_);
	my $text = '';
	foreach my $repo (sort values %$self) {
		$text .= $repo->dumpConfig;
	}
	return $text;
}

# --- sync all repos from their sources ---
sub sync {
	my $self = _self(shift);
	foreach my $repo (values %$self) {
		vprint 0, "Syncing ". $repo->name ."\n";
		$repo->sync;
	}
}

# --- load packages for each repo ---
sub loadPackages {
	my $self = shift;
	foreach my $key (keys %$self) {
		$self->{$key}->loadPackages;
	}
}

# === Load Sources YAML Files ===============================================
# --- load all source config files ---
sub loadSources {
	my ($self, $args) = (_self(shift, @_), nchash @_);

	# --- search ETC_PATH for sources config files ---
	foreach my $path (split ':', $ENV{ETC_PATH}) {
		next unless -d $path;

		# --- load sources.yaml ---
		$self->loadSource("$path/sources.yaml")
			if -e "$path/sources.yaml";

		# --- load the files in sources.d ---
		next unless -d "$path/sources.d";
		opendir SDIR, "$path/sources.d";
		foreach my $file (sort readdir SDIR) {
			next unless -f "$path/sources.d/$file";   # ignore non-files
			next unless $file =~ /\.(?:yaml|yml)$/i;  # ignore non-YAML files
			$self->loadSource("$path/sources.d/$file");
		}
		closedir SDIR;
	}

	# --- trim all sources except a given repo --
	if ($args->{repo}) {
		my $rname = $args->{repo};

		# --- unknown reop specified ---
		unless ($self->{$rname}) {
			vprint -1, "error: unknown repository '$rname'\n";
			exit 1;
		}

		foreach my $key (keys %$self) {
			delete $self->{$key} unless $key eq $rname;
		}
	}
}

# --- load a single source config file ---
sub loadSource {
	my ($self, $file) = @_;

	# --- read the file and render envars ---
	my $content = interpolate(readfile($file));

	# --- parse the YAML, set defaults and create ::Repository objects ---
	my $yaml = new iTools::YAML(YAML => $content);
	while (my ($name, $hash) = each %$yaml) {

		# --- defaults ---
		$hash->{name}     ||= $name;  # short name
		$hash->{priority} ||= 999;    # default priority: very low

		# --- split tags into an array ref ---
		$hash->{tags} = [ map { lc } grep { $_ } split /\s+/, $hash->{tags} || '' ]
			unless ref $hash->{tags};

		$self->{$name} = new Portia::Repository(%$hash);
	}
}

# === Query Methods =========================================================
# --- wrapper for ::Repository's matches method ---
sub findRepo {
	my ($self, %params) = (_self(shift), @_);

	my $found;
	foreach my $repo (values %$self) {
		my $matched = $repo->matches(%params);
		unless ($matched) { next }                  # no match
		unless ($found) { $found = $matched; next } # first match

		# --- matched repo is higher priority ---
		$found = $matched
			if $matched->{priority} < $found->{priority};
	}

	return $found;
}

1;
