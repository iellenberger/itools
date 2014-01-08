package iTools::YAML::Lite;
use base qw( Exporter );
our $VERSION="0.0.1";

@EXPORT_OK = qw(
	liteyaml2hash yaml2hash
	litehash2yaml hash2yaml
);
#! TODO: inline this to remove external dependancy
use iTools::File qw( readfile writefile );

use Data::Dumper; $Data::Dumper::Indent=$Data::Dumper::Sortkeys=$Data::Dumper::Terse=1; # for debugging only

use strict;
use warnings;

# === Class Variables =======================================================
# --- accessor defaults ---
our $TAB    = 8;
our $INDENT = 3;

# === Exports ===============================================================
sub yaml2hash { liteyaml2hash(@_) }
sub liteyaml2hash {
}

sub hash2yaml { litehash2yaml(@_) }
sub litehash2yaml {
}

# === Object Construction ===================================================
# --- force parser into XML mode ---
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref($this) || $this;

	# --- parse constructor's parameters ---
	foreach my $key (keys %args) {
		my $value = $args{$key};

		$key =~ /^(?:Text|YML|YAML)$/i and do { $self->text($value);    next };
		#$key =~ /^(?:File|FileName)$/i and do { $self->load($value); next };
		$key =~ /^(?:File|FileName)$/i and do { $self->file($value); next };
		$key =~ /^(?:Hash|Data)$/i and do     { $self->hash($value);    next };
		$key =~ /^(?:Indent)$/i and do        { $self->indent($value);  next };
		$key =~ /^(?:Tab|Tabs)$/i and do      { $self->tab($value);     next };
	}

	return $self;
}

# === Accessors =============================================================
sub file { shift->_var(file => @_) }
sub text { shift->_var(text => @_) }

sub hash {
	my $self = shift;

	# --- set hash if given ---
	return $self->_var(hash => @_) if @_;

	# --- if we don't have a hash, try to find contant and parse it ---
	unless ($self->_var('hash')) {

		# --- parse and return text ---
		return $self->parse if $self->text;

		# --- try to load file if we have no text ---
		$self->load
			if ! $self->text && $self->file && -e $self->file;

		# --- parse text if we have it ---
		$self->parse if $self->text;
	}

	# --- return hash ---
	return $self->_var('hash');
}

# --- tab expansion (for parsing) ---
sub tab { shift->_var(tab => @_) }
# --- tab string (ro) ---
sub tstr {
	my $tab = shift->tab;
	$tab = $TAB if !$tab || $tab eq '-1';      # $TAB if 0, -1 or undef
	return (' ' x $tab) if $tab =~ /^-?\d+$/;  # space expanded numeric
	return $tab;                               # string
}
# --- tab value (ro): numeric or string length ---
sub tval {
	my $tab = shift->tab;
	return 0 unless defined $tab;              # 0 for undef
	return $tab if $tab =~ /^-?\d+$/;          # numeric
	return length $tab;                        # string length
}

# --- indent (for rendering) ---
sub indent {
	my $self = shift;
	my $indent = $self->_var(indent => @_);

	# --- default indent ---
	$indent = $INDENT unless defined $indent;

	# --- if indent is a number, return the naumber of spaces ---
	return (' ' x $indent) if $indent =~ /^\d+$/;
	return $indent;
}

# --- Private Accessors -----------------------------------------------------

# --- flag indicating the content was parsed ---
sub _parsed { shift->_var(_parsed => @_) }

# --- array of parsed lines ---
sub _plines {
	my $self = shift;
	my $lines = $self->_var(_plines => @_);
	$lines = $self->_var(_plines => [])
		unless $lines;
	return $lines;
}

# --- implement shift and unshift for _plines ---
sub _pindex { shift->_var(_pindex => @_) || 0 }
sub _pshift {
	my $self = shift;

	# --- get line array and index ---
	my $plines = $self->_plines;
	my $pindex = $self->_pindex;

	# --- return undef if we're at the end of the array ---
	return undef if $pindex >= @$plines;

	# --- return the line and increase the index ---
	my $pline = $plines->[$pindex];
	$self->_pindex($pindex + 1);
	return $pline;
}
sub _punshift {
	my $self = shift;
	my $pindex = $self->_pindex;
	$pindex-- if $pindex > 0;
	return $self->_pindex($pindex);
}

# === Parsing and Rendering =================================================

# --- parse text into hash ---
sub parse {
   my $self = shift;
	my $text = $self->text(@_);  # optional param (text)

	# --- try to load file if we have no text ---
	$text = $self->load
		if ! $text && $self->file && -e $self->file;

	# --- return empty hash if we have no text ---
	return $self->hash({}) unless $text;

	# --- parse the tsxt into lines ---
	$self->parselines;

	$self->hash($self->parse2hash);

	return $self->hash;
}

# --- convert text into series of parsed lines ---
sub parselines {
	my $self = shift;

	# --- set / predeclare vars ---
	my $plines = $self->_plines;
	my @istack;
	my $text = $self->text;
	my ($tab, $tval, $tstr) = ($self->tab, $self->tval, $self->tstr);

	my $linenum = 0;
	foreach my $linestr (split /\r?\n/, $text) {

		# --- split indent and content ---
		my ($indent, $content) = ($linestr =~ /^([\s-]*)(.*?)$/);

		# --- merge doctags into content ---
		($indent, $content) = ('', $linestr)
			if $indent =~ /^---\s/;

		# --- initialize message array ---
		$plines->[$linenum]->{message} = [];

		# --- detect and handle tabbed indents ---
		if ($indent =~ /\t/) {

			# --- generate message if tab found ---
			push @{$plines->[$linenum]->{message}}, {
				type    => 'tab',
				message => 'tab used for indent',
			};

			# --- replace tabs ---
			$indent =~ s/\t/$tstr/g;
		}

		# --- set indent and content ---
		$plines->[$linenum]->{indent}  = $indent;
		$plines->[$linenum]->{content} = $content;

		# --- calculate depth ---
		unshift @istack, $indent unless @istack;  # initialize indent stack if needed
		if ($indent ne $istack[0]) {              # depth has changed

			# --- depth increased, push indent onto stack ---
			if (length $indent > length $istack[0]) {
				# --- remove dashes for array markers ---
				if ($indent =~ /^\s+-\s+$/) { unshift @istack, ' ' x length $indent; }
				# --- all other indents as-is ---
				else                        { unshift @istack, $indent; }
			}

			# --- depth decreased, find parent and adjust indent stack ---
			elsif (length $indent < length $istack[0]) {
				
				# --- find the parent indent ---
				while (@istack) {
					shift @istack;
					last if @istack && $indent eq $istack[0];
				}

				# --- error: tried to pop too many indents off the stack ---
				if (@istack < 1 || $indent ne $istack[0]) {
					push @{$plines->[$linenum]->{message}}, {
						type    => 'parse',
						message => 'indent mismatch, no parent found',
					};
					unshift @istack, $indent;
				}
			}

			# --- mismatched indent string ---
			else {
				# --- generate error unless we have an array marker ---
				push @{$plines->[$linenum]->{message}}, {
					type    => 'parse',
					message => 'indent match, correct length, wrong characters',
				} unless $indent =~ /^\s+-\s+$/;
			}
		}

		# --- set indent depth ---
		$plines->[$linenum]->{depth} = @istack - 1;

#print "'". join("'", @istack) ."'\n";
#printf "%3d %d %s|%s\n", $linenum, @{$plines->[$linenum]}{qw( depth indent content )};

		$linenum++;
	}

#print Dumper($plines);
	$self->_plines($plines);

	#! TODO: I think this belongs in parse()
	# --- generate warning/error message ---
	$self->pMessage;

}

# --- convert parsed lines into data structure ---
sub parse2hash {
	my $self = shift;
	my $plines = $self->_plines;
	my $pindex = $self->_pindex;

	return if $pindex >= @$plines;

	# --- predeclare/set a few vars ---
	my $array;
	my $hash;
	my $depth = $plines->[$pindex]->{depth};




	while (my $lhash = $self->_pshift) {

#print " --> $lhash->{content}\n";

		# --- detect if we're parsing an array ---
		if ($lhash->{indent} =~ /^\s*-\s*$/) {
			$array ||= [];
#print "... array tag\n";
			if ($hash) {
				push @$array, $hash;
#print "... pushing hash ". Dumper($hash);


				$hash = undef;
			}
		}


		# --- ignore certain lines ---
		next if $lhash->{content} =~ /^\s*#/;  # ignore comments
		next if $lhash->{content} =~ /^---\s/; # ignore doctags

		# --- pop out of loop if last element detected at current depth ---
		if ($lhash->{depth} < $depth) {
			$self->_punshift;
			last;
		}

		if ($lhash->{content} =~ /^(.*?)\s*:\s*(.*?)\s*$/) {
			my ($key, $value) = ($1, $2);

			# --- text block detected ---
			if ($value =~ /^[>|]$/) {
				$hash->{$key} = $self->_parseblock($value);
				next;
			}

			# --- data structure detected ---
			if ($value eq '') {
				$hash->{$key} = $self->parse2hash;
				next;
			}

			$hash->{$key} = $value;

		} elsif ($array) {
			push @$array, $lhash->content;
		} else {
				# --- generate error unless we have an array marker ---
				push @{$lhash->{message}}, {
					type    => 'parse',
					message => 'unknown format',
				};
		}
	}

#print Dumper($hash);

	if ($array) {	
		push @$array, $hash; 
		return $array;
	} else {
		return $hash;
	}
}

# --- parse ans return a block of text ---
sub _parseblock {
	my ($self, $type) = (shift, shift || '|');
	my $plines = $self->_plines;
	my $pindex = $self->_pindex;

	return if $pindex >= @$plines;

	# --- predeclare/set a few vars ---
	my @lines;
	my $depth = $plines->[$pindex]->{depth};

	# --- push text block content onto an array ---
	while (my $lhash = $self->_pshift) {

		# --- pop out of loop if end of block is detected ----
		if ($lhash->{depth} != $depth) {
			$self->_punshift;
			last;
		}

		push @lines, $lhash->{content};
	}

	# --- join array of lines into a single text block and return ---
	my $connector = $type eq '|' ? '\n' : ' ';
	return join $connector, @lines;
}

# --- parse ans return an array ---
sub _parsearray {
	my ($self, $plines) = (shift, shift, shift || 0);
}

# --- generate a parser message ---
sub pMessage {
	my $self = shift;
	my $plines = $self->_plines;

	my ($tab, $tval) = ($self->tab, $self->tval);

	# --- generate error/warning string ---
	my $errcount = {
		warning => 0,  # info and warnings
		error   => 0,  # fatal errors
	};
	my $msgtxt = '';  # warning/error message
	for (my $ii = 0; $ii < @$plines; $ii++) {

		foreach my $message (@{$plines->[$ii]->{message}}) {

			# --- determine the error level ---
			my $errlevel = 0;  # -1 = ignore; 0 = warn; 1 = error (fatal)

			# --- parse messages always fatal ---
			$errlevel = 1 if $message->{type} eq 'parse';

			# --- tab messages depend on tab value ---
			if ($message->{type} eq 'tab') {
				SWITCH: {
					!defined $tab && do { $errlevel = -1; last };
					$tval == -1   && do { $errlevel = 1;  last };
					$tval == 0    && do { $errlevel = 0;  last };
					$tval > 0     && do { $errlevel = -1; last };
				}
			}

			# --- count message type and build message ---
			SWITCH: {
				$errlevel == -1 && do { last };
				$errlevel == 0 && do {
					$msgtxt .= sprintf "WARNING line %2d - %s\n", $ii, $message->{message};
					$errcount->{warning}++;
					last;
				};
				$errlevel == 1 && do {
					$msgtxt .= sprintf "ERROR   line %2d - %s\n", $ii, $message->{message};
					$errcount->{error}++;
					last;
				};
			}
		}
	}

#print Dumper($errcount);

	# --- print message and exit on fatal ---
	if ($errcount->{error}) {
		print $msgtxt;
		exit 1;
	} elsif ($errcount->{warning}) {
		print $msgtxt;
	}

	return $msgtxt;
}


# === Utility Methods =======================================================
# --- load a file ---
sub load {
	my ($self, $file) = @_;

	# --- error checks ---
	unless ($file) { print STDERR "iTools::YAML::Lite->load: no filename given\n"; exit 1 }
	unless (-e $file) { print STDERR "iTools::YAML::Lite->load: invalid file '$file'\n"; exit 1 }

	# --- read the file and set stuff in $self ---
	$self->text(readfile($file));
	return $self->file($file);
}

# --- accessor method (from iTools::Core::Accessor) ---
sub _var {
	my ($self, $key) = (shift, shift);

	# --- get the value ---
	unless (@_) {
		return $self->{$key} if exists $self->{$key};
		return undef;
	}

	# --- delete the key if value = undef ---
	unless (defined $_[0]) {
		my $value = $self->{$key};  # store the old value
		delete $self->{$key};       # delete the key
		return $value;              # return the old value
	}

	# --- set and return the value ---
	return $self->{$key} = shift;
}

1;

=head1 NAME

iTools::YAML::Lite - ...

=head1 SYNOPSIS

  use iTools::YAML::Lite;

=head1 DESCRIPTION

B<iTools::YAML::Lite> is is a class used to ...

=head1 CONSTRUCTOR

=over 4

=item new iTools::YAML::Lite(...);

Creates and returns a new object for the class.

=back

=head1 ACCESSORS

=head2 Universal Accessors

An accessor labelled as B<universal> is an accessor that allows you to get, set and unset a value with a single method.
To get a the accessor's value, call the method without parameters.
To set the value, pass a single parameter with the new or changed value.
To unset a value, pass in a single parameter of B<undef>.

For details on B<universal> accessors, see the iTools::Core::Accessor(3pm) man page.

=over 4

=item $obj->B<file>([I<FILENAME>])

Get/set the name of the file to be read/written.

=item $obj->B<text>([I<YAML>])

Get/set the raw YAML text.

=item $obj->B<tab>([I<VALUE>])

Get/set the tab-indent translation value for YAML parsing.  Can be set to any of the following values:

=over 4

=item C<undef> (default)

Tabs will treated by the parser as 8 spaces (same setting I<VALUE> to C<8>).

=item C<0> (loose mode)

Tabs will generate a warning; tabs will be treated as 8 spaces.

=item C<-1> (strict mode)

Tabs will generate an error; parsing will fail.

=item Numeric

Tabs will translated into the requisite number of spaces.

=item String

Tabs will be replaced with the given string.

=back

=item $obj->B<indent>([I<VALUE>])

Get/set the indent for YAML rendering.  If numeric, that number of spaces will be used, otherwise it will be treated as a string.

The default value is C<3>.

=item $obj->B<hash>([I<VALUE>])

=back

=head1 TODO

=over 4

=item B<Rewrite for more linear parsing>

The method I used to break down the text is rather messed up.
It needs to be rewritten to use a more linear method.

=back

=head1 KNOWN ISSUES AND BUGS

=over 4

=item B<???>

=back

=head1 REPORTING BUGS

Report bugs in the iTools' issue tracker at
L<https://github.com/iellenberger/itools/issues>

=head1 AUTHOR

Ingmar Ellenberger

=head1 COPYRIGHT

Copyright (c) 2001-2013 by Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<https://github.com/iellenberger/itools/blob/master/LICENSE>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 DEPENDENCIES

strict(3pm) and warnings(3pm),

=head1 SEE ALSO

iTools::Core::Accessor(3pm)

=cut
