package Puma::Core::Config;
use base qw( iTools::Core::Accessor Puma::Object::Serial );
our $VERSION = 0.1;

use Puma::Tools::Hash 'merge';
use iTools::XML::Simple 'simplexml2hash';
use Data::Dumper; $Data::Dumper::Indent = 1; # for debugging only
use Storable qw( dclone );

use strict;
use warnings;

# === Globals ===============================================================
$Puma::Core::Config::COREFILE = '/ITOOLS_ROOT/etc/puma/puma.xml';

# === Constructor ===========================================================
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref($this) || $this;

	# --- create a dummy config in case there isn't a config ---
	$self->_setCoreDefaults;

	# --- get params ---
	my $file = $self->corefile;
	while (my ($key, $value) = each %args) {
		#! TODO: add URL option; replace File option?
		lc $key eq 'file' && do { $file = $self->corefile($value) };
	}

	# --- load the core config or a serialized object ---
	#! TODO: process URLs instead of extensions
	if ($file =~ /\.(?:xml|puma)$/) { $self->loadCore }
	else                            { $self = $self->unserialize($file) }

	# --- load local configs ---
	$self->loadLocal unless $self->core->{config}->{cascade} ne 'on';

	return $self;
}

# === Accessors =============================================================
sub core     { shift->_var(_core => @_) }
sub corefile { shift->_varDefault($Puma::Core::Config::COREFILE, _corefile => @_) }
sub local {
	my $self = shift;
	return $self->{_local} || {} unless @_;
	my $key = shift;
	return $self->{_local}->{$key} unless @_;
	return $self->{_local}->{$key} = shift;
}

# === Loading Config Files ==================================================
# --- core config file ---
sub loadCore {
	my ($self, $file) = @_;

	# --- set the corefile if given ---
	$self->corefile($file) if $file;

	# --- load the core config ---
	$file = $self->corefile;
	return unless defined $file && -e $file;  # no file
	my $xml = simplexml2hash(File => $file);
	return unless $xml && ref $xml eq 'HASH'; # not XML
	my $config = $self->core($xml->{puma});
	$self->_setCoreDefaults;

	# --- munge the directory tags ---
	if (exists $config->{directory}) {
		# --- presets ---
		my $docroot = $ENV{DOCUMENT_ROOT} || '/dev/null';
		my $dirs = $config->{directory};
		$dirs = [ $dirs ] unless ref $dirs eq 'ARRAY';
		$config->{directory} = {};

		# --- loop through each dir ---
		foreach my $dir (@$dirs) {
			next unless $dir->{name};
			my $dirname = $dir->{name} =~ m|^/| ? $dir->{name} : "$docroot/$dir->{name}";
			delete $dir->{name};
			$self->local($dirname, $dir);
		}
		delete $config->{directory};
	}


	return $config;
}

# --- local config files ---
sub loadLocal {
	my $self = shift;

	# --- get values from the core config ---
	my $core    = $self->core;
	my $cascade = $core->{config}->{cascade};
	my $file    = $core->{config}->{file};
	return unless $cascade;

	# --- walk through the dirs loading configs ---
	my @dirs = $self->_getLocalPath;
	my $dirhash = $self->local || {};
	DIR: while (@dirs) {
		my $dir = join('/', @dirs);

		CONFIG: {
			# --- config already loaded ---
			next CONFIG if exists $dirhash->{$dir} && defined $dirhash->{$dir};
			# --- file does not exist ---
			next CONFIG unless -e "$dir/$file";

			# --- load XML, next if not valid ---
			my $xml = simplexml2hash(File => "$dir/$file");
			next CONFIG unless $xml && ref $xml eq 'HASH';

			# --- save the hash ---
			$dirhash->{$dir} = $xml->{puma};
		};

		# --- a bit of local processing ---
		my $config = $dirhash->{$dir}->{config};
		# --- stop cascade? ---
		last DIR if exists $config->{cascade} && $config->{cascade} ne 'on';
		# --- new local file name? ---
		$file = $config->{file} if exists $config->{file};
		
		pop @dirs;
	}

	# --- set dir and return ---
	$self->{_local} = $dirhash; #! BUG: this is a hack - may want to re-examine
	return $dirhash;
}

# --- return a generated config ---
sub getConfig { defined $_[0]->{_genConfig} ? $_[0]->{_genConfig} : $_[0]->genConfig }
# --- generate a new config hash specific to the page ---
sub genConfig {
	my $self = shift;

	# --- clone the configs ---
	my $config = dclone($self->core);
	my $dirhash = dclone($self->local);

	# --- merge local configs ---
	my @dirs = $self->_getLocalPath; # || ();
	while (@dirs) {
		my $dir = join('/', @dirs);

		CONFIG: {
			# --- no local config ---
			next CONFIG unless exists $dirhash->{$dir} && defined $dirhash->{$dir};
			# --- merge the local config into core ---
			merge($config, $dirhash->{$dir});
		};
		# --- next dir ---
		pop @dirs;
	}

	# --- cleanup and return ---
	delete $config->{directory};
	return $self->{_genConfig} = $config;
}

# === Puma::Object::Serial Overrides ========================================
sub serial {
	my $self = dclone(shift);
	delete $self->{_genConfig};
	return $self;
}

# === Private Methods =======================================================
# --- set defaults for core config ---
sub _setCoreDefaults {
	my $self = shift;
	my $config = $self->core || {};           # base config hash
	$config->{config}->{cascade} ||= 'on';    # cascase = on
	$config->{config}->{file}    ||= '.puma'; # local filename = .puma
	return $self->core($config);
}
# --- return an array of config directories ---
sub _getLocalPath {
	return unless defined $ENV{DOCUMENT_ROOT};
	my $docroot = $ENV{DOCUMENT_ROOT};
	$docroot =~ s/\/$//; # remove trailing slash
	my $path = ($ENV{PATH_TRANSLATED} =~ m|^$docroot/(.*?)/[^/]*$|)[0] || undef;
	return ($docroot) unless defined $path;
	return ($docroot, split( /\//, $path));
}

1;

=head1 NAME

Puma::Core::Config - base configuration object for Puma

=head1 SYNOPSIS

  use Puma::Core::Config;
  my $config = new Puma::Core::Config(File -> 'filename');

=head1 DESCRIPTION

The Puma::Core::Config is the bootstrap configuration object for Puma.

=head1 METHODS

=over 4

=item B<Constructor>

=over 4

=item B<new Puma::Core::Config>([File => FILE])

The object constructor.

=back

=item B<Accessors>

=over 4

=item $obj->B<core>([CORE])

Sets or gets the core configuration hash.
B<loadCore> populates this value.

=item $obj->B<corefile>([FILE])

Sets or gets the name of the core configuration file.
If a filename was given in the constructor, the value for B<FILE> is automatically set.

=item $obj->B<local>([DIR [,HASH]])

Sets local B<DIR>ectory configuration B<HASH>es, or gets local configuration hashes for a B<DIR>ectory.
If no B<DIR> is given, all hashes will be returned.

=item $obj->B<getConfig>()

Returns a previously generated configuration hash for the page, or a newly generated one (i.e. B<genConfig>()) if none exists.
This method reduces the processing requirements if the configuration needs to be retrieved more than once in a processing cycle.

Note that generated configurations do not survive serialization.
A thawed object will always call B<genConfig>() the first time B<getConfig>() is called.

=back

=item B<Functional Methods>

=over 4

=item $obj->B<loadCore>()

Loads the core configuration file (as reported by B<corefile>) into the object.
Does nothing if the core configuration file name is not set.

See the L<CONFIGURATION FILES> section for details on the configuration file format.

=item $obj->B<loadLocal>()

Loads configurations local to the page being parsed.
See the L<CONFIGURATION FILES> section for details on how local configurations are processed.

=item $obj->B<genConfig>()

Generates and returns a configuration hash specific to the page being parsed.
See the L<CONFIGURATION FILES> section for details on how local configurations are processed.


=back

=back

=head1 CONFIGURATION FILES

<?xml version="1.0" encoding="UTF-8"?>
<puma>

  <!-- configuration file parsing options
    cascade on/off - read local '.puma' files? (think .htaccess)
    file NAME      - alternate name for local '.puma' files
  -->
  <config cascade="on" file=".puma" />

  <!-- directory specific configs
    name DIR - name of dir
      assumes DIR as an extension of documentroot
      leading '/' implies filesystem root
  -->
  <directory name="a">
    <!-- insert any overrides here -->
    <config cascade="off"/>
  </directory>

</puma>

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

Copyright (c) 2001-2005 by Ingmar Ellenberger.

Distributed under The Artistic License.
For the text the license, see L<http://puma.sourceforge.net/license.psp>
or read the F<LICENSE> in the root of the Puma distribution.

=head1 DEPENDENCIES

Storable(3pm), strict(3pm) and warnings(3pm) (stock Perl);
Puma::Core::Engine(3pm), Puma::Object::Serial(3pm),
Puma::Tools::Hash(3pm), iTools::XML::Simple(3pm)

=head1 SEE ALSO

=cut
