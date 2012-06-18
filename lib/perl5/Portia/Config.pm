package Portia::Config;
use base qw( iTools::Core::Accessor HashRef::Maskable );

use Data::Dumper; $Data::Dumper::Indent=$Data::Dumper::Sortkeys=$Data::Dumper::Terse=1; # for debugging only
use Config;
use Cwd qw( abs_path );
use FindBin qw( $Bin $RealBin $RealScript );
use iTools::File qw( readfile );
use iTools::Verbosity qw( vprint );
use Portia::Sources;
use Portia::Tools qw( source uniq );
use Storable qw( dclone );
use Switch;

use strict;
use warnings;

# === Class-Level Declarations ==============================================
# --- persistant instance of object ---
our $INSTANCE;

# --- prototypes ---
sub _shift3(\@);

# === Constructor and Construtor-like Methods ===============================
# --- new, blank object ---
sub new {
	my ($this, %args) = @_;
	my $self = $INSTANCE = bless {}, ref $this || $this;

	# --- save the original env ---
	$self->{_originalENV} = dclone(\%ENV);

	# --- parse incoming parameters ---
	while (my ($key, $value) = each %args) {
		switch (lc $key) {
			case m/^import/ { $self->importEnv($value) }
			else            { $self->{$key} = $value }
		}
	}

	# --- load the sources files ---
	$self->reload;

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

# === Variable Mapping ======================================================

# --- generate and return the variable map ---
sub maps {
	my $self = shift;

	# --- generate a new mapping if one doesn't exists ---
	unless ($self->{_maps}) {
		my @maps;

		# --- a mapping template for all envvars ---
		# format: shortname, longname, default
		my @template = map { $_ eq 'undef' ? undef : $_ } qw(
			undef  OS_NAME               undef
			undef  OS_DIST               undef
			undef  OS_VERSION            undef
			undef  HW_ARCH               undef

			BR     BIN_ROOT              undef
			undef    PORTIA_BIN          BIN_ROOT/bin/portia
			LR       LIB_ROOT            BIN_ROOT/lib/portia
			IR     INSTALL_ROOT          /usr/local

			PR     PORTIA_ROOT           undef
			PL       PORTIA_LIB          PORTIA_ROOT/var/lib/portia
			DB         DB_ROOT           PORTIA_LIB/db
			DBD          DB_DIR          DB_ROOT/CATEGORY/PACKAGE
			DR         DISTFILES_ROOT    PORTIA_LIB/distfiles
			DD           DISTFILES_DIR   DISTFILES_ROOT/CATEGORY/PACKAGE
			EP       ETC_PATH            PORTIA_ROOT/etc/portia

			TR       TMP_ROOT            PORTIA_ROOT/var/tmp
			WR         WORK_ROOT         TMP_ROOT/portia
			PW           PWORK_DIR       WORK_ROOT/CATEGORY/PACKAGE
			DL             DOWNLOAD_DIR  PWORK_DIR/download
			WD             WORK_DIR      PWORK_DIR/work
			SD             STAGE_DIR     PWORK_DIR/stage

			RU     REPO_URI              undef
			PU     PACKAGE_URI           REPO_URI/packages/CATEGORY/PACKAGE
			PU     DISTFILES_URI         REPO_URI/distfiles/CATEGORY/PACKAGE

			P      PACKAGE               undef
			V      VERSION               undef
			R      REVISION              undef
			C      CATEGORY              undef
			PV     undef                 P-V
			PVR    undef                 P-VR
			VR     undef                 V-R
			CP     undef                 C/P
			CPV    undef                 CP/PV
			CPVR   undef                 CP/PVR
		);

		# --- generate and save the mapings ---
		push @maps, [ _shift3 @template ] while @template;
		$self->{_maps} = [ @maps ];
	}

	# --- return the mappings ---
	return wantarray ? @{$self->{_maps}} : $self->{_maps};
}

# --- resolves maps to a hash ---
sub mapsHash {
	my $self = shift;

	# --- generate a new hash if one doesn't exists ---
	unless ($self->{_mapsHash}) {
		my $mapsHash;
		foreach my $map ($self->maps) {
			my ($short, $long, $default) = @$map;
			# --- map short keys ---
			if ($short) {
				if    ($long)    { $mapsHash->{$short} = $long }
				elsif ($default) { $mapsHash->{$short} = $default }
			}
			# --- map long keys ---
			$mapsHash->{$long} = $default if $long;
		}

		$self->{_mapsHash} = $mapsHash;
	}

	# --- return the mapping hash ---
	return wantarray ? %{$self->{_mapsHash}} : $self->{_mapsHash};
}

# === Utility Methods =======================================================

# --- print configuration to screen ---
sub dumpConfig {
	my $self = _self(shift);
	my $text = '';

	foreach my $map ($self->maps) {
		my $name = $map->[1] || $map->[0];
		$text .= sprintf "%-4s  %-15s %s\n",
			$map->[0] || '',
			$map->[1] || '',
			$self->{$name} || '';
	}

	return $text;
}

# === Configuration Builders ================================================
# --- one method to rule them all ---
sub reload {
	my $self = _self(shift);

	# --- reload original %ENV and clear current config ---
	%ENV = %{$self->{_originalENV}} if $self->{_originalENV};
	foreach my $key (keys %$self) {
		next if $key =~ /^_/;
		delete $self->{$key} unless $self->{_hard}->{$key};
	}

	# --- set the verbosity ---
	use iTools::Verbosity qw( verbosity );
	$ENV{VERBOSITY} = verbosity;

	# --- reload the imports ---
	foreach my $key (keys %{$self->{_imports} || {}}) {
		$self->hardSet($key => $self->{_imports}->{$key});
	}

	# --- reload everything ---
	$self->_loadOS;
	$self->_loadHardware;
	$self->_loadEnv;

	return $self;
}

# --- load info about the operating system ---
sub _loadOS {
	my $self = _self(shift);
	my ($dist, $osver);

	$self->hardSet(OS_NAME => $Config{osname});

	# --- OS distribution and version ---
	OSDIST: {
		# --- Darwin / OS-X ---
		$self->{OS_NAME} eq 'darwin' and do {
			if (-e '/usr/bin/osascript') {
				$dist = 'os-x';
				$osver = qx[ /usr/bin/osascript -e 'tell app "Finder" to version' ];
				chomp $osver;
			} else {
				$dist = 'macos';
				$osver = ($Config{myuname} =~ /kernel version ([\w\.]*)/)[0] || '';
			}
			last;
		};
		# --- linux ---
		$self->{OS_NAME} =~ /linux/i and do {
			if (-e '/etc/redhat-release') {
				#! TODO: should I just make this redhat?
				$dist = $Config{osname} =~ /centos/ ? 'centos' : 'redhat';
				my $release = readfile('/etc/redhat-release');
				$osver = ($release =~ /release (\S*)/)[0] || '';
			}
			last;
		};

		#! TODO: Debian, Ubuntu, other distros
	};

	$self->hardSet(OS_DIST => $dist, OS_VERSION => $osver);
}

# --- load info about the hardware ---
sub _loadHardware {
	my $self = shift;
	#! BUG: darwin reports i386 all the time. Is this correct?
	# --- set HW_ARCH ---
	$Config{myarchname} =~ /i386/   and $self->hardSet(HW_ARCH => 'i386');
	$Config{myarchname} =~ /i686/   and $self->hardSet(HW_ARCH => 'i686');
	$Config{myarchname} =~ /amd64/  and $self->hardSet(HW_ARCH => 'x86_64');
	$Config{myarchname} =~ /x86_64/ and $self->hardSet(HW_ARCH => 'x86_64');
}

# --- configure the Portia environment ---
sub _loadEnv {
	my $self = shift;
	# --- set the essential values ---
	$self->hardSet(PORTIA_ROOT => $ENV{PORTIA_ROOT} || abs_path("$Bin/.."));
	$self->hardSet(BIN_ROOT    => $ENV{BIN_ROOT}    || abs_path("$RealBin/.."));
	$self->hardSet(PORTIA_BIN  => $ENV{PORTIA_BIN}  || abs_path("$RealBin/$RealScript"));

	# --- generate a list of initial config dirs ---
	my @etcpath = uniq(
		"$self->{PORTIA_ROOT}/etc/portia",
		abs_path("$Bin/..") ."/etc/portia",
		abs_path("$RealBin/..") ."/etc/portia",
		"$ENV{HOME}/.portia",
	);

	# --- look for 'preload' files, source the first one and stop ---
	foreach my $preload (map { "$_/portia.preload" } reverse @etcpath) {
		next unless -e $preload;
		my $newvars = source { import => 0 }, $preload;
		$self->hardSet(%$newvars);
		last;
	}

	# --- set ETC_PATH and resolve all other keys ---
	$self->softSet(ETC_PATH => $self->{ETC_PATH} || join ":", grep { -e } @etcpath);
	$self->resolveAll;

	# --- import configs ---
	foreach my $conf (split ':', $self->{ETC_PATH}) {
		my $newvars = source { import => 0 }, "$conf/portia.conf";
		$self->hardSet(%$newvars);
		$self->resolveAll;
	}
}

# --- set keys so they won't be overwritten ---
sub hardSet {
	my ($self, %args) = @_;
	while (my ($key, $value) = each %args) {
		if (defined $value && $value ne '') {
			# --- hard-set the key ---
			$self->{$key} = $ENV{$key} = $value;
			$self->{_hard}->{$key} = 1;
		} else {
			# --- unset the key and make it soft ---
			delete $self->{$key};
			delete $ENV{$key};
			delete $self->{_hard}->{$key};
		}
	}
}

# --- set keys if they're overwritable ---
sub softSet {
	my ($self, %args) = @_;

	while (my ($key, $value) = each %args) {
		# --- don't set any keys marked hard ---
		next if $self->{_hard}->{$key};

		if (defined $value) {
			$self->{$key} = $ENV{$key} = $value;
		} else {
			delete $self->{$key};
			delete $ENV{$key};
		}
	}
}

sub resolveAll {
	my $self = shift;

	delete $self->{_resolved};                # clear resolver cache
	$self->resolve(keys %{$self->mapsHash});  # resolve all keys
	delete $self->{_resolved};                # clear the cache again
}

sub resolve {
	my ($self, @keys) = @_;
	$self->{_depth}++;

	my $mapsHash = $self->mapsHash;

	my $success = 1;
	foreach my $key (@keys) {

		# --- ignore any bad keys ---
		next unless $key;

		# --- ignore keys already resolved ---
		if ($self->{_resolved}->{$key}) {
			$success = 0 unless defined $self->{$key};
			next;
		}

		# --- ignore hard-set keys and mark as resolved ---
		if ($self->{_hard}->{$key}) {
			$success = 0 unless defined $self->{$key};
			$self->{_resolved}->{$key} = 1;
			next;
		}

		# --- get the key's template ---
		my $template = $mapsHash->{$key};

		# --- ignore blank/undef templates and mark as resolved ---
		if (!$template) {
			$success = exists $self->{$key} && defined $self->{$key} ? 1 : 0;
			$self->{_resolved}->{$key} = 1;
			next;
		}

		# --- split out keys in template ---
		my @parts = grep { $_ } split /[^A-Z_]+/, $template;

		# --- set the resolved flag before recursing ---
		$self->{_resolved}->{$key} = 1;

		# --- resolve keys in template ---
		my $resolved = $self->resolve(@parts);

		# --- special case for 'PVR' ---
		if ($key eq 'VR' && !$resolved && $self->resolve('V')) {
			$resolved = 1;
			$self->softSet(VR => $self->{V});
			next;
		}

		# --- if template keys didn't resolve, don't render the template ---
		unless ($resolved) {
			$success = 0;
			next;
		}

		# --- replace keys in template and set the key in self ---
		foreach my $part (@parts) { $template =~ s/$part/$self->{$part}/ }
		$self->softSet($key => $template);
	}

	return $success;
}

sub selectVersion {
	my ($self, $version) = (_self(shift), shift);

	$self->hardSet(%$version);
	$self->resolveAll;

	return $version;
}

sub selectRepo {
	my ($self, $repo) = (_self(shift), shift);
	my $reponame;

	# --- load the repo by name if we didn't get an object ---
	if (ref $repo eq 'Portia::Repository') {
		$reponame = $repo->name;
	} else {
		$reponame = $repo;
		$repo = findRepo Portia::Sources(Name => $reponame);
	}

	# --- throw error of not a repo object ---
	unless (ref $repo eq 'Portia::Repository') {
		vprint -1, "Unable to select repository ". ("'$reponame'" || "undef") ."\n";
		vprint 0,  "   not a valid repository\n";
		exit 1;
	}

	# --- load the vars ---
	$self->hardSet(%{$repo->env});
	$self->resolveAll;

	return $repo;
}

# --- import environment variables ---
sub importEnv {
	my $self = shift;

	# --- build the parameter list ---
	my @params;
	foreach my $param (@_) {
		next unless defined $param;

		# --- parameter is an array ref ---
		if (ref $param eq 'ARRAY') {
			push @params, @$param;
		}
		# --- praameter is a hash ref ---
		elsif (ref $param eq 'HASH') {
			while (my ($key, $value) = each %$param) {
				push @params, "$key=$value";
			}
		}
		# --- parameter is a string ---
		else {
			push @params, $param;
		}
	}

	foreach my $param (@params) {
		my ($key, $value) = ($param =~ /^(\w+)(?:=(.*?))?$/);
		unless ($key) {
			vprint -1, "invalid key in import";
			exit 1;
		}

		$value = $ENV{$key}
			unless $value;

		$self->hardSet($key => $value);
		$self->{_imports}->{$key} = $value;
	}
}

# === Private Methods and Functions =========================================
# --- shift 3 values ---
sub _shift3(\@) {
	my $args = shift;
	return (shift @$args, shift @$args, shift @$args);
}

1;
