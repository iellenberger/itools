package Puma::Core::Parser;

# use Data::Dumper; $Data::Dumper::Indent = 1; # for debugging only
use Puma::Core::RegEx qw( reTagParser reAttribute );
use iTools::File qw( readfile );

use strict;
use warnings;

# === Constructor ===========================================================
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref($this) || $this;

	# --- get params ---
	while (my ($key, $value) = each %args) {
		lc $key eq 'file' && $self->file($value);
		lc $key eq 'text' && $self->text($value);
	}

	return $self;
}

# === Accessors =============================================================
sub file { defined $_[1] ? $_[0]->{_file} = $_[1] : $_[0]->{_file} }
sub text { defined $_[1] ? $_[0]->{_text} = $_[1] : $_[0]->{_text} }
sub loadFile {
	my $self = shift;

	# --- load file if we have one ---
	if (my $file = $self->file(shift)) {
		# --- make sure we use the right path ---
		my $path = (($ENV{PATH_TRANSLATED} || '') =~ m|^(.*/)[^/]+$|)[0] || '';
		$file = $path . $file unless $file =~ m|^/|;
		# --- return text if file ---
		return $self->text(readfile($file));
	}

	# --- otherwise return text ---
	return $self->text;
}

# === Methods ===============================================================
sub parse {
	my $self = shift;
	$self->text($_[0]) if defined $_[0];

	# --- load the file if no text exists ---
	unless ($self->text) {
		# --- return if nothing to parse ---
		return [] unless defined $self->loadFile;
	}
	# --- predefine things ---
	my $text  = $self->text;
	my $stack = [[]];
	my $regex = reTagParser('[^<>\s]*:');

	# --- walk through file parsing as we go ---
	TAG: while ($text =~ m/$regex/gc) { # '/o' to compile regex once
		my ($pretext, $tagtext) = ($1, $2);

		# --- process pretext ---
		push @{$stack->[0]}, { body => $pretext }
			if defined $pretext && $pretext ne '';

		# --- comments ---
		$tagtext =~ m|^<\!--.*-->$|ms && do {
			push @{$stack->[0]}, { body => $tagtext };
			next TAG;
		};

		# --- any tag starting with a colon ---
		$tagtext =~ m|^<(:\S*)(\s.*?)/>$|ms && do {
			my $tag = { label => $1, body => $2 };
			$tag = $self->_splitTag($tagtext) unless $tag->{label} =~ /^:=?$/;
		
			# --- special processing for the :include tag ---
			if ($tag->{label} eq ':include') {
				my $tag = $self->_splitTag($tagtext);
# my $file = $tag->{attribute}->{file}; eval qq[\$file = "$file"] if $file =~ /\$/;
				my $parser = new Puma::Core::Parser(File => $tag->{attribute}->{file});
				push @{$stack->[0]}, @{$parser->parse};
				next TAG;
			}

			# --- push the tag on the stack and get the next tag ---
			push @{$stack->[0]}, $tag;
			next TAG;
		};

		# --- ending tag ---
		$tagtext =~ m|^</| && do {
			#! TODO: throw error if tag name does not match
			shift @$stack;
			next TAG;
		};

		# --- split the tag into label and attributes ---
		my $tag = $self->_splitTag($tagtext);
		push @{$stack->[0]}, $tag;

		# --- selfending tag ---
		$tagtext =~ m|/>$| && do { next TAG };

		# --- beginning tag ---
		$tag->{body} = [];
		unshift @$stack, $tag->{body};
	}

	# --- push the last bit on the stack ---
	my $pretext = ($text =~ m/\G(.*)/gs)[0];
	push @{$stack->[0]}, { body => $pretext }
		if defined $pretext && $pretext ne '';

	return $stack->[0];
}

sub _splitTag {
	my ($self, $text) = @_;

	# --- trim the opening and closing braces ---
	$text =~ s|^</?(.*?)/?>$|$1|sm;

	# --- get the tag label ---
	my $tag;
	$tag->{label} = ($text =~ m|^(\S*)\s*|gc)[0];

	# --- parse out attributes ---
	my $regex = reAttribute();
	while ($text =~ /$regex/gc) {
		my ($key, $value) = ($1, _first($2, $3, $4, $5) || 1);
		$tag->{attribute}->{$key} = $value;
	}

	return $tag;
}

# --- return the first defined value in an array ---
sub _first { foreach (@_) { return $_ if defined $_ } return undef }

1;

=head1 NAME

Puma::Core::Parser - the base Puma tag parser

=head1 SYNOPSIS

  use Puma::Core::Parser;
  my $parser = new Puma::Core::Parser(File => 'foo.puma');
  my $tagtree = $parser->parse;

=head1 DESCRIPTION

B<Puma::Core::Parser> converts documents marked with Puma tags into a machine consumable data structure.
It is used by the B<Puma::Core::Engine> to convert documents to executable Perl code.

=head1 METHODS

All public methods in the B<Puma::Core::Parser> class can take one of two parameters:

=over 5

=item B<TEXT> - the text to parse

=item B<FILE> - the file that contains the B<TEXT> to parse.

=back

The methods listed below describe their exact usage.

=over 4

=item B<new Puma::Core::Parser>([Text => TEXT,] [File => FILE,])

The B<Puma::Core::Parser> constructor.
Takes one of two parameters as shown above and stores them in the object.
If both parameters are given, the B<parse>() method will ignore B<FILE>.

Returns a new B<Puma::Core::Parser> object.

=item $obj->B<text>([TEXT])

Accessor for the B<TEXT> parameter.
If B<TEXT> is given, it will be stored in the object.
If no parameters are given, it will return the stored B<TEXT>.

Always returns the current/new value of B<TEXT>.

=item $obj->B<file>([FILE])

Accessor for the B<FILE> parameter.
If B<FILE> is given, it will be stored in the object.
If no parameters are given, it will return the stored B<FILE>.

Always returns the current/new value of B<FILE>.

=item $obj->B<loadFile>([FILE])

Reads the contents of B<FILE> and stores or replaces B<TEXT> with the contents of the file.
If B<FILE> is not given, it will use the current stored value for B<FILE>.

Returns B<TEXT>.

=item $obj->B<parse>([TEXT])

Parses B<TEXT> and returns a parse tree (see below).
If B<TEXT> is not given, it will use the current stored value for B<TEXT>.
If B<TEXT> has no current value, it will load the contents of B<FILE> via B<loadFile>().

B<parse>() uses the following rules to parse B<TEXT>:

=over 4

=item B<Bodies, Comments and Ignored Tags>

All content that is not recognized as a tag are stored as a body:

  { body => the body content }

Comments that contain valid parsable tags will be correctly ignored,
but due to the complexity of the processing for this task,
it is possible that multiple body hashes are stored consecutively in the parse tree.

Any tags that do not match one of the rules below is considered to be a body.

=item B<Tags with Embedded Colons> - <foo:bar key="value">

These are the meat of the tags consumed by B<Puma::Core::Parser>.
They are stored in the parse tree as follows:

  { label      => the tag label ('foo:bar' for the example)
    attributes => { a hash of tag attributes (key => 'value') }
    body       => [ and array of body/tags within the tag ] }

Selfending tags will not have a body.

=item B<Tags Starting with Colons> - <:.*/>

Stores the labelled tag with the contents of the tag as a body:

  { label => from ':' to the first whitespace character
    body  => from the end of the label to '/>' }

Note that these tags must be selfending.

There is one exception to this rule ...

=item B<Include Tags> - <:include file="FILE" />

The B<:include> tag instantiates a new B<Puma::Core::Parser> and inserts the contents of the parsed B<FILE> at the tag location.
This process does not test for recursion, so be vewwy, vewwy caewful.

=back

=back

=head1 THE PARSE TREE

The value returned from the B<parse>() method is a tree'd data structure.

Given the following text:

  1  <html><head>
  2    <title name="<:= $mytitle />">
  3  </head><body>
  4    <!-- this is the body -->
  5    <object:drawBody output="terse" tagged/>
  6    <object:getFooter>
  7      <p>$object->{footer}</p>
  8      <object:showAddress/>
  9    </object:getFooter>
  10 </body></html>

The parse tree would look like this:

  1  [ { body => '<html><head>\n   <title name="' },
  2    { label => ':=',
         body => ' $mytitle '
       },
  3    { body => '\n</head><body>\n   ' },
  4    { body => '<!-- this is the body -->' },
       { body => '\n   ' },
  5    { label => 'object:drawBody',
         attributes => {
           output => 'terse',
           tagged => 1
         }
       },
       { body => '\n      ' },
  6    { label => 'object:getFooter',
         body => [
  7        { body => '\n      <p>$object->{footer}</p>\n   ' },
  8        { label => 'object:showAddress' },
           { body => '\n   ' },
  9      ],
  10   { body => '\n</body></html>', },
     ];

I added line numbers so you could see how things match up.
Notice that comments occupy their own hash and the result is a number of consecutive 'body' hashes.
Also note that I took some liberty with the '\n's to make it more readable (normally they would be actual linefeeds).

It is useful to use B<Data::Dumper> to see the results of your parsing efforts.

=head1 EXAMPLES

=head1 TODO

  - error checking - and lots of it!
  - unit tests for error conditions

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

strict(3pm) and warnings(3pm) (stock Perl);
Puma::Core::RegEx(3), iTools::File(3)

=head1 SEE ALSO

Data::Dumper(3pm),
Puma::Core::Engine(3pm)

=cut
