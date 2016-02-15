package iTools::Script::Options;
use base qw( iTools::Core::Accessor );
our $VERSION = "0.1";

use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging only

use Cwd;
use FindBin qw( $Script $RealBin $RealScript );
use Getopt::Long;
use iTools::Verbosity qw( vprint );
use iTools::Term::ANSI qw( color cpush cpop );

use strict;
use warnings;

# --- persistant instance of object ---
our $INSTANCE;
our $mancoreopts = <<MANCORE;
	=head1 CORE OPTIONS

	These options are provided by the iTools::Script::Options(3pm) library.
	See the documentation there for additional details.

	=over 4

	=item B<-?>, B<--help>; B<--man>

	Display a short usage message, or the full manual page (sic).

	=item B<-q>, B<--quiet>
	
	=item B<-v>[B<vvv>], B<--verbose>
	
	=item B<-V>, B<--verbosity> LEVEL

	Do things quietly or loudly.
	There are several incremental levels of verbosity (LEVEL in brackets) :

	    -qq    (-2) suppress all messages
	    -q     (-1) only show error messages
	           (0)  normal output
	    -v     (1)  extended progress
	    -vv    (2)  debugging output and executed commands
	    -vvv   (3)  command execution details

	=item B<--[no]color>

	Enable or disable colored terminal output.

	=item B<--version>

	Show the version number

	=back
MANCORE

# === Constuctor and Constructor-like methods ===============================
# --- new, blank object ---
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref $this || $this;
	
	# --- intrinsic default values ---
	my $defaults = {
		verbosity => 0,
		debug     => 0,
		color     => 1,
	};
	
	# --- parse incoming parameters ---
	while (my ($key, $value) = each %args) {
		lc $key eq 'options'     && $self->options(@{$value});
		lc $key eq 'usage'       && $self->usagetext($value);
		lc $key eq 'minargs'     && $self->minargs($value);
		lc $key eq 'required'    && $self->required($value);
		lc $key eq 'manvars'     && $self->manvars($value);
		lc $key eq 'usageformat' && $self->usageformat($value);
		lc $key eq 'user'        && $self->user($value);
		$key =~ /^defaults?$/i   && map { $defaults->{$_} = $value->{$_} } keys %$value;
	}

	# --- set default values ---
	map { $self->{$_} = $defaults->{$_} unless exists $self->{$_} } keys %$defaults;

	return $INSTANCE = $self;
}
sub load { $INSTANCE || shift->new(@_) }

# === Accessors =============================================================
sub options     { shift->_varArray(_options => @_) }
sub verbosity   {
	my $self = shift;
	iTools::Verbosity::verbosity(@_) if @_;
	return $self->_varDefault(0, verbosity => @_);
}
# --- verbosity level explicitly set on command line ---
sub cliVerbosity { shift->_var(_cliVerbosity => @_) }

sub user        { shift->_varArray(_user => @_) }
sub argv        { shift->_varArray(_argv => @_) }
sub minargs     { shift->_varDefault(0, _minargs => @_) }
sub required    { shift->_varArray(_required => @_) }
sub manvars     { shift->_varDefault({}, _manvars => @_) }
sub usageformat { shift->_varDefault("[options] ARGS ...", _usageformat => @_) }
sub usagetext {
	my $self = shift;

	# --- reformat the incoming text to make sure it's indented correctly ---
	unshift @_, _undent(shift)
		if @_ && defined $_[0];

	$self->_var(_usage => @_)
}

# --- return core CLI flags ---
sub coreFlags {
	my $self = shift;

	my $flags = "--verbosity ". $self->verbosity;
	$flags .= " --nocolor" unless $self->{color};
	$flags .= " --debug" if $self->{debug};

	return $flags;
}

# === Configuration =========================================================
sub parse {
	my $self = shift;
	$self = $self->new(@_) unless ref $self;  # create object if we don't have one

	# --- save off the CLI args ---
	$self->argv(@ARGV);

	# --- parse the command line options ---
	Getopt::Long::Configure('bundling');
	GetOptions($self,
		# --- core parameters ---
		'help|?+', 'man+',    # usage and man pages
		'quiet|q+',           # do things quietly
		'verbose|v+',         # do things loudly
		'verbosity|V=n',      # set an explicit verbosity level
		'version+',           # show the version

		# --- misc options ---
		'color!',             # colored output
		'debug+',             # debug output

		# --- options for user switching ---
		'isorundir=s',        # set the running directory for new user (only used internally)

		# --- user arguments ---
		$self->options,
	);

	# --- show usage or man page ---
	$self->{help}    && do { $self->usage() };
	$self->{man}     && $self->man;
	$self->{version} && do { print "$::VERSION\n"; exit 0 };

	# --- minimum arguments required ---
	$self->usage("A minimum of ". $self->minargs ." argument". ($self->minargs > 1 ? 's' : '') ." is required")
		if @ARGV < $self->minargs;

	# --- verbosity ---
	$self->usage("can't be quiet and verbose at the same time")
		if $self->{quiet} && $self->{verbose};
	$self->verbosity(($self->{verbose} || 0) - ($self->{quiet} || 0))
		unless $self->{verbosity};
	$self->cliVerbosity($self->verbosity)
		if defined $self->{quiet} || defined $self->{verbose} || defined $self->{verbosity};
	delete @{$self}{qw(quiet verbose)};
	iTools::Verbosity::verbosity($self->{verbosity});

	# --- colored output ---
	iTools::Term::ANSI::colored($self->{color});

	# --- required keys ---
	foreach my $key ($self->required) {
		$self->usage("required argument '--$key' missing")
			unless exists $self->{$key};
	}

	# --- run as alternate user and chdir after we're done ---
	if ($self->{isorundir}) { chdir $self->{isorundir} }
	else                    { $self->setUser }

	return $self;
}

# === Usage and Error Message ===============================================
sub usage {
	my ($self, $error) = @_;

	vprint -1, "\n". cpush('r') ."error: ". cpop ."$error\n\n" if $error;

	my $usageformat = $self->usageformat;
	#! TODO: check for undef in ->usagetext
	vprint 0, <<USAGE ."\n". $self->usagetext ."\n\n$Script version $::VERSION\n\n";
usage: $Script [-qv] $usageformat

Options:

   -?, --help          display this message
      --man               display the manual page for $Script
   -q[q], --quiet      do things quietly
   -v[vvv], --verbose  do things loudly
   --nocolor           disable colored output
USAGE

	exit 1;
}

# === Manpage Generation ====================================================
sub man {
	my $self = shift;

	require Pod::Text::Termcap;
	require Term::ReadKey;

	# --- get vars and set defaults ---
	my $vars = $self->manvars;
	$vars->{PROGRAM} ||= $RealScript;
	$vars->{VERSION} ||= $::VERSION;
	$vars->{COREOPTS} ||= $mancoreopts; $vars->{COREOPTS} =~ s/^\t//mg;

	#! TODO: detect if this var has a space before it. Add a space if it doesn't.
	#! TODO: figure out a better way to format this se we don't have to put a space in front of it.
	$vars->{SYNOPSIS} ||= "$vars->{PROGRAM} {-?|--man}\n $vars->{PROGRAM} [-qv[vv]] ". $self->usageformat() ."\n";

	# --- get the terminal size ---
	my $cols = (Term::ReadKey::GetTerminalSize())[0] || 78;

	# --- read the file ---
	open FILE, "$RealBin/$RealScript";
	my $content = ''; { local $/; $content = <FILE>; }
	close FILE;

	# --- interpolate variables ---
	foreach my $key (keys %$vars) {
		$content =~ s/[\$=]{$key}(?=\W)/$vars->{$key}/sg;
		$content =~ s/[\$=]$key(?=\W)/$vars->{$key}/sg;
	}

	# --- generate the manpage ---
	my $manpage;
	my $parser = new Pod::Text::Termcap(sentence => 0, width => $cols - 2);
	if ($^V ge v5.10.0) {
		$parser->{opt_width} = $cols - 2;  # hack to work around a bug
		$parser->output_string(\$manpage);
		$parser->parse_string_document($content);
	} else {
		require IO::String;
		my $in = new IO::String($content);
		my $out = new IO::String;
		$parser->parse_from_filehandle($in, $out);
		$out->setpos(0); { local $/; $manpage = <$out>; }
	}

	# --- display it with less ---
	open LESS, '| less -r';
	print LESS $manpage;
	close LESS;

	exit 1;
}

# === Other Functions =======================================================
# --- run script as another user ---
sub setUser {
	my ($self, @users) = @_;
	@users = $self->user unless @users;

	# --- get the canonical user (first element in array) ---
	my $user = $users[0];

	# --- return if we're already the correct user or no user is defined ---
	return unless $user;
	#! TODO: foreach my  ...
	return if $ENV{USER} eq $user;

	# --- problems arise if user has no read perms to cwd ---
	my $cwd = cwd;
	chdir '/tmp';

	# --- re-execute the command as the correct user ---
	vprint 1, "Running script as user ". color(c => $user) ."\n";
	my $cmd = "sudo -H -u $user $RealBin/$RealScript --isorundir $cwd ". join(' ', $self->argv);
	vprint 2, '>'. color(c => $cmd) ."\n";
	exec $cmd;
}

# === Private Subs and Methods ==============================================
# --- unindent a block of text ---
sub _undent {
	my $text = shift;

	# --- replace tabs with 3 spaces ---
	$text =~ s/\t/   /g;

	# --- find the smallest indent ---
	my $indent = ' ' x 100;
	foreach my $line (split /\n/, $text) {
		next unless $line =~ /^(\s*)\S/;  # ignore blank lines
		$indent = $1 if length($1) < length($indent);
	}

	# --- unindent the block of text ---
	$text =~ s/^$indent//mg;

	# --- trim leading and trailing space ---
	$text =~ s/^\s*\n//s;
	$text =~ s/\s*$//s;
	return '' unless $text;

	# --- indent with 3 spaces if first character is a '-' ---
	$text =~ s/^/   /mg if ($text =~ /^\s*(\S)/m)[0] eq '-';

	return $text;
}

1;

=head1 NAME

iTools::Script::Options - custom extension of Getopt::Long

=head1 SYNOPSIS

 use iTools::Script::Options;

 my $options = parse iTools::Script::Options(
    Options => [ 'field|f=s', 'flag|g+' ],
    Required => [ 'field' ],
    UsageFormat => "[-g] --field FIELD",
    Usage => "
       -g, --flag         a flag
       -f, --field FIELD  some field (required)
    ",
    User => 'somebodyelse',
 );

=head1 DESCRIPTION

B<iTools::Script::Options> is a custom replacement for Getopt::Long(3pm) with various extensions.

=head1 EXAMPLES

=head1 CONSTRUCTORS

=over 4

=item new iTools::Script::Options(...)

=item load iTools::Script::Options(...)

=item parse iTools::Script::Options(...)

=back

=head1 ACCESSORS

=head2 Universal Accessors

An accessor labelled as B<universal> is an accessor that allows you to get, set and unset a value with a single method.
To get a the accessor's value, call the method without parameters.
To set the value, pass a single parameter with the new or changed value.
To unset a value, pass in a single parameter of B<undef>.

For details on B<universal> accessors, see the iTools::Core::Accessor(3pm) man page.

=over 4

=item $obj->B<options>([I<VALUE>])

=item $obj->B<verbosity>([I<VALUE>])

=item $obj->B<user>([I<VALUE>])

=item $obj->B<argv>([I<VALUE>])

=item $obj->B<minargs>([I<VALUE>])

=item $obj->B<required>([I<VALUE>])

=item $obj->B<manvars>([I<VALUE>])

=item $obj->B<usageformat>([I<VALUE>])

All of the methods B<universal> accessors to the URI component of the same name.
They may be used to fetch individual values for a parsed URI or to set/change values for an new or existing URI.

All of these accesors perform no processing beyond storing values.
See the methods below for information on content parsing.

=item $obj->B<usagetext>([I<VALUE>])

=item $obj->B<coreFlags>([I<VALUE>])

=back

=head1 TODO, KNOWN ISSUES AND BUGS

=over 4

=item ToDo: B<Complete the Manpage>

Lots to do there.

=item Feature: B<Flexible Verbosity>

Make it so that the verbosity can go up to an arbitrary level, not just the default 3.

=item Feature: B<Inheritable Verbosity>

Provide a separate method that can set the default verbosity level if nothing
was provided on the command line - essentially a post-instantiation default.

=back

=head1 REPORTING BUGS

Report bugs in the iTools' issue tracker at
L<https://github.com/iellenberger/itools/issues>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2012 by Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<https://github.com/iellenberger/itools/blob/master/LICENSE>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 DEPENDENCIES

strict(3pm), warnings(3pm);
Cwd(3pm), FindBin(3pm), Getopt::Long(3pm);
iTools::Core::Accessor(3pm), iTools::System(3pm), iTools::Term::ANSI(3pm);

=head1 SEE ALSO

iTools::Core::Accessor(3pm),
Getopt::Long(3pm),

=cut
