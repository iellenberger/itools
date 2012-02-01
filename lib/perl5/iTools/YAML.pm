package iTools::YAML;
use base qw( iTools::Core::Accessor HashRef::Maskable );
$VERSION = 0.1;

use Carp qw( confess );
use Data::Dumper; $Data::Dumper::Indent=1; $Data::Dumper::Sortkeys=1; # for debugging
use iTools::File qw( readfile writefile );
use Storable qw( dclone );
use YAML::Any;

use strict;
use warnings;

# === Constructor/Destructor ================================================
sub new {
	my ($this, %args) = @_;
	my $self = $this->mhash;

	# --- process settings parameters ---
	while (my ($key, $value) = each %args) {
		next unless defined $value;
		lc $key eq 'indent'        && $self->indent($value);
		lc $key eq 'quote'         && $self->quote($value);
		lc $key eq 'strict'        && $self->strict($value);
	}

	# --- process data parameters ---
	while (my ($key, $value) = each %args) {
		next unless defined $value;
		$key =~ /^file(?:name)?$/i && $self->read($value);
		lc $key eq 'yaml' && $self->parse($value);
		lc $key eq 'hash' && $self->hash($value);
	}

	return $self;
}

# === Accessors =============================================================
# --- these won't show up in each() 'cause we're using HashRef::Maskable ---
sub file   { shift->_var(_file   => @_) }
sub quote  { shift->_var(_quote  => @_) }
sub strict { shift->_var(_strict => @_) }

# === Indent Mamagement =====================================================
# --- public accessor ---
sub indent   { my $self = shift; $self->_varDefault($self->_indent, _indent => @_) }
# --- private accessor ---
sub _indent  { shift->_varDefault(2, __indent => @_) }

# --- calculate indent from block of text ---
sub _calcIndent {
	my $self = shift;
	my $yaml = shift || $self->_yaml;
	
	# --- no yaml, fall back to default ---
	return $self->_indent(undef) unless $yaml;

	# --- find minimum indent ---
	my $minspace = 9;  # single tab width + 1
	foreach my $line (split /\n/, $yaml) {
		my $space = ($line =~/^( *)\w/)[0];
		$minspace = length($space) if $space && length($space) < $minspace;
	}

	# --- set indent ---
	return $self->_indent($minspace == 9 ? undef : $minspace);
}

sub _tab2spaces {
	my $self = shift;
	my $yaml = shift || $self->_yaml;

	# --- no yaml, return empty string ---
	return '' unless $yaml;

	# --- strict mode, don't convert ---
	return $self->_yaml($yaml) if $self->strict;

	# --- convert tabs to spaces ---
	my $indent = ' ' x $self->indent;
	my $newyaml = '';
	foreach my $line (split /\n/, $yaml) {
		my ($pre, $post) = ($line =~ /^(\s*)(.*?)$/);
		if ($pre && $pre =~ s/\t/$indent/g) {
			$line = $pre . $post || '';
		}
		$newyaml .= $line ."\n";
	}

	# --- return and set converted YAML ---
	return $self->_yaml($newyaml);
}

# --- re-indent YAML ---
sub _redent {
	my $self = shift;

	# --- get YAML ---
	my $yaml = shift || $self->_yaml || return '';

	# --- old and new indent ---
	my $indent = ' ' x $self->_calcIndent($yaml);
	my $redent = shift || ' ' x $self->indent;

	# --- convert indents to new value ---
	my $newyaml = '';
	foreach my $line (split /\n/, $yaml) {
		my ($pre, $post) = ($line =~ /^(\s*)(.*?)$/);
		if ($pre && $pre =~ s/$indent/$redent/g) {
			$line = $pre . $post || '';
		}
		$newyaml .= $line ."\n";
	}
	
	return $newyaml;
}

# === YAML Parsing and Rendering ============================================
# --- temporary YAML storage ---
sub _yaml  { shift->_var(__yaml => @_) }

# --- convert YAML to hash ($self) ---
sub parse {
	my $self = shift;
	my $yaml = shift || $self->_yaml;

	# --- no yaml, throw error ---
	confess "error: No YAML submitted for parsing" unless $yaml;

	# --- set YAML tmp, calculate indent and convert tabs ---
	$self->_yaml($yaml);
	$self->_calcIndent;
	$self->_tab2spaces;

	# --- pass YAML to parser and clear temporary ---
	my $hash = Load($self->_yaml);
	$self->_yaml(undef);

	# --- merge hash to self and return self ---
	$self->hash($hash);
	return $self;
}

# --- convert $self to YAML ---
sub render {
	my $self = shift;

	# --- process render flags ---
	local $YAML::Indent = $self->indent;
	if (YAML::Any->implementation eq 'YAML::Syck') {
		$YAML::Syck::SingleQuote = 1 if $self->quote;
		$YAML::Syck::Headless = 1 unless $self->strict;
	}

	# --- generate YAML ---
	my $selfhash = $self->hash;
	my $yaml = keys(%$selfhash) ? Dump($selfhash) : '';

	# --- post-process anything else ---
	if (YAML::Any->implementation eq 'YAML::Syck') {
		$yaml = $self->_redent($yaml);
	} else {
		#! TODO: add quotes
	}

	# --- clear out extra spaces at EOL ---
	$yaml =~ s/: $/:/mg unless $self->strict;

	# --- make sure we're actually headless ---
	$yaml =~ s/^---\n// unless $self->strict;

	return $yaml;
}

# === Hash Content Mamagement ===============================================
# --- copy/clone self to/from hash ---
sub hash {
	my $self = shift;

	# --- return a copy of $self ---
	return $self->_clone unless @_;

	# --- clear the hash on undef ---
	return $self->clear if !defined $_[0];

	# === if we got here, it's a set operation ---
	# --- predeclare vars ---
	my $hash;

	# --- got a hashref ---
	if (ref $_[0] eq 'HASH') { $hash = dclone(shift) }
	# --- got a real hash ---
	elsif (not @_ % 2)     { $hash = dclone({@_}) }
	# --- invalid parameters ---
	else {
		confess __PACKAGE__ ."->hash() requires a hash of hashref as a parameter(s)\n".
			"   instead I got\n\n". Data::Dumper->Dump([\@_], ['@ARG']) ."\n  ";
	}

	# --- clear self, merge hash to self and return ---
	$self->clear;
	map { $self->{$_} = $hash->{$_} } keys %$hash;
	return $self->_clone;
}

# --- return unblessed clone of given hash or self ---
sub _clone {
	my ($self, $original) = @_;
	my $clone = dclone($original || $self);
	return { map { $_ => $clone->{$_} } keys %$clone };
}

# === General Methods =======================================================

# --- read YAML from file and convert ---
sub read {
	my ($self, $file) = @_;
	$file = $file ? $self->file($file) : $self->file;
	
	my $content = readfile($file);
	return $self->parse($content);
}

# --- convert to YAML and write ---
sub write {
	my ($self, $file) = @_;
	$file = $file ? $self->file($file) : $self->file;

	return writefile($file, $self->render);
}

# --- validate YAML ---
sub validate {
	#! TODO: finish this
}

# --- clear $self in prep for new data ---
sub clear { map { delete $_[0]->{$_} } keys %{$_[0]} }

1;

=head1 NAME

iTools::YAML - OO interface for loosely parsing YAML

=head1 SYNOPSIS

  use iTools::YAML;
  my $yaml = new iTools::YAML;

  $yaml->read('myfile.yaml');
  $yaml->{myname} = { first => 'John', last => 'Schmidt' };
  my $text = $yaml->write;

  $yaml->clear;
  $yaml->indent(3);
  $yaml->strict(1);
  $yaml->quote(1);

  $yaml->parse($text);
  delete $yaml->{myname};
  print $yaml->render;

=head1 DESCRIPTION

B<iTools::YAML> provides a OO feature wrapper around Perl's YAML classes that provides:

=over 4

=item * YAML validation and better error messages

=item * Parsing and rendering non-standard YAML

=back

B<iTools::YAML> does not contain a parser in the class itself.
It relies on the parser provided by YAML::Any(3pm), so you
will need to have some YAML class installed for this to work.

=head1 CONSTRUCTOR

=over 4

=item B<new iTools::YAML>([KEY => VALUE [, ...]])

Creates a new B<iTools::YAML> object.
All parameter are optional and case-insensitive
and the values can be set or changed at any time via accessors (see L<ACCESSORS>).

=over 4

=item B<File> or B<Filename>

The filename use by the B<read>() and B<write>() methods if no filename is given.
This value will be reset if a filename is passed to wither method.

=item B<Indent>

Sets the indent depth.
If not set, it either scans incoming YAML for the smallest indent
or uses the default value for the parser.

#If you set this to a non-numeric value, it will use the string as the indent.
#(Can you say, "YAML with tabs!"?)

=item B<Quote>

Some YAML parsers (like the one in node.js) require all values with spaces to be quoted.
If denined, this option forces all such values to be quoted on render.

This option is disabled by default, uses double quotes if set to '1', or used the given string if the value is non-numeric.

=item B<Strict>

Enables strict parsing, off by default.

B<iTools::YAML> allows you to indent your YAML with tabs.
Leaving this option off converts all tabs to spaces as defined by 'Indent'.

=item B<YAML>

Seeds the object with the given YAML text.

=item B<Hash>

Merges the given hashref into the object.

=back

=back

=head1 ACCESSORS

=over 4

=item $obj->B<file>([I<VALUE>])

=item $obj->B<quote>([I<VALUE>])

=item $obj->B<strict>([I<VALUE>])

=item $obj->B<indent>([I<VALUE>])

All accessors are also available as constructor parameters.
See L<CONSTRUCTOR> earlier in this document for details.

All accessors are universal.
For details on universal accessors, see the iTools::Core::Accessor(3pm) man page.

To get a the accessor's value, call the method without parameters.
To set the value, pass a single parameter with the new or changed value.
To unset a value, pass in a single parameter of B<undef>.

=back

=head1 METHODS

=over 4

=item $obj->B<parse>(I<YAML>)

=item $obj->B<read>([I<FILENAME>])

The parse() method converts a block of B<YAML> text and into $obj.
read() does the same for the text in the given B<FILENAME>.
If B<FILENAME> is not given, it tries to use the default filename given via the constructor or file() accessor.
If B<FILENAME> is given, it sets that as the default filename.

Both return $obj.

=item $obj->B<render>()

=item $obj->B<write>([I<FILENAME>])

Renders $obj into a block of YAML text.
write() also writes the content to B<FILENAME>.
If B<FILENAME> is not given, it tries to use the default filename given via the constructor or file() accessor.
If B<FILENAME> is given, it sets that as the default filename.

Both return the generated YAML.

=item $obj->B<hash>([I<HASHREF>])

Returns a deep copy of $obj as a new, untied, unblessed hash.

=item $obj->B<clear>()

Clears $obj.
Returns $obj.

=back

=head1 TODO

=over 4

=item B<Complete validate() method>

=item B<Allow for Rendering with Tabs>

Already partially implemented in private _redent() method.

=back

=head1 KNOWN ISSUES AND BUGS

=over 4

=item B<quote() only works for YAML::Syck>

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

strict(3pm) and warnings(3pm),
Carp(3pm),
iTools::Core::Accessor(3pm),
iTools::File(3pm),
Storable(3pm),
YAML::Any(3pm)

=head1 SEE ALSO

iTools::Core::Accessor(3pm)

=cut
