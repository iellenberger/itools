package iTools::XML::Parser;
$VERSION=0.1;

use Data::Dumper; $Data::Dumper::Indent = 1;

use strict;
use warnings;

# === Object Construction ===================================================
# --- force parser into XML mode ---
sub new {
	my ($this, %args) = @_;
	my $self = bless {}, ref($this) || $this;

	# --- parse constructor's parameters ---
	foreach my $arg (qw(Text XMLHandlers Object ParamFormat)) {
		if (exists $args{$arg} && defined $args{$arg}) {
			$self->{$arg} = $args{$arg};
			delete $args{$arg};
	}	}

	# --- default values ---
	$self->{ParamFormat} ||= 'HASH';

	return $self;
}

# === Parser ================================================================
sub parse {
	my ($self, %args) = @_;

	# --- parse parameters ---
	foreach my $arg (qw(Text XMLHandlers Object ParamFormat)) {
		if (exists $args{$arg} && defined $args{$arg}) {
			$self->{$arg} = $args{$arg};
			delete $args{$arg};
	}	}

	# --- load the text to be parsed ---
	my $text = $self->{Text} || '';
	return undef unless $text;

	# --- cleanup ---
	$text =~ s/\r\n/\n/sg;             # remove carriage returns
	$text =~ s/^(.*?)(<[^\?\!])/$2/sg; # remove comments and XML header
	my $header = $1 || '';

	# --- build the root tag ---
	my $tag = {label => ':parser', type => 'root', params => {} };
	$tag->{params} = $self->{ParamFormat} eq 'HASH' ? {} : [];

	# --- grab the regular expression for finding the tags ---
	# --- store rules in $self so we only have to grab them once ---
	$self->{_rules} = reTagParser();

	# --- recurse! ---
	$self->{_depth} = 0;
	$self->{text} = $text;
	my $tree = $self->_buildTree($tag);
	delete $self->{_depth};

	return unless $tree;

	# --- pop the :parser head tag ---
	$tree = $tree->[3];

	# --- we have the tree, so walk it ---
	$self->_callXMLHandler('Init', $header);
	$self->_walk(@$tree);
	$self->_callXMLHandler('Final');

	return $tree;
}

# === Handler Accessor ======================================================
sub _callXMLHandler {
	my ($self, $handlername) = (shift, shift);
	return unless $self->{XMLHandlers}->{$handlername};

	my $handler = $self->{XMLHandlers}->{$handlername};
	$self->{Object} ? &{$handler}($self->{Object}, @_) : &{$handler}(@_);
}

# --- private method called recursively to walk the tree ---
sub _walk {
	my ($self, $tagname, $params, @ptree) = @_;

	# --- call 'Start' handler ---
	if (ref $params eq 'HASH') {
		$self->_callXMLHandler('Start', $tagname, %{$params});
	} else {
		$self->_callXMLHandler('Start', $tagname, @{$params});
	}

	# --- walk the tag array ---
   foreach my $child (@ptree) {
		ref $child ?
			$self->_walk(@$child) :
			$self->_callXMLHandler('Char', $child);
	}

	# --- call 'End' handler ---
	$self->_callXMLHandler('End', $tagname);
}

#	_buildTag - a helper function to build a tag structure
#
#	This method takes two or more parameters and returns a tag structure in the
#	format specified above.
#
#	The two parameters are the tag label and a hasshref of tag paramters.  All
#	following fields are text or references to child tags.

sub _buildTag {
	my ($self, $label, $params, @children) = @_;
	return [ $label, $params || undef, @children ];
}

# === Encode and Decode XMl Entities ========================================
#! TODO: export these
sub xmlEncode {
	shift if ref $_[0];  # loose $self if used
	local $_ = ($_[0] || return $_[0]);
	s/&/&amp;/g; s/</&lt;/g; s/>/&gt;/g; s/'/&apos;/g; s/"/&quot;/g;
	return $_;
}
sub xmlDecode {
	shift if ref $_[0];  # loose $self if used
	local $_ = ($_[0] || return $_[0]);
	s/&amp;/&/g; s/&lt;/</g; s/&gt;/>/g; s/&apos;/'/g; s/&quot;/"/g;
	return $_;
}

# === Private Methods =======================================================

#	_buildTree - Build the tag tree (structure)
#
#	This method calls itself recursively to build a tree of tags.

sub _buildTree {
	my ($self, $tag) = @_;

	# --- safety: don't recurse more than 40 levels deep ---
	return if $self->{_depth} > 40;
	$self->{_depth}++;

	# --- use precompiled rules to search through text and build tag tree ---
	my @children;
	TAG: while ($self->{text} =~ m/$self->{_rules}/gco) { # '/o' to compile regex once

		if (defined $1) {
			push @children, '' unless @children;  # ensure there is a value on the array

			if (ref $children[@children - 1]) {
				push @children, $1;  # push text as a child
			} else {
				$children[@children - 1] .= $1;  # concatenate if previous element a string
		}	}

		# --- special consideration for comments ---
		my $tagtext= $2;
		if ($tagtext=~ /<!--/) {
			push @children, '' unless @children;  # ensure there is a value on the array

			$children[@children - 1] .= $tagtext
				unless ref $children[@children - 1];  # concatenate if previous element a string

			next TAG;
		}

		my $child = $self->_splitTag($tagtext);

		if ($child->{type} =~ /selfending/) {
			push @children, $self->_buildTag($child->{label}, $child->{params});
		} elsif ($child->{type} eq 'beginning') {
			push @children, $self->_buildTree($child);
		} elsif ($child->{type} eq 'ending') {
			last if $child->{label} eq $tag->{label} ||
				$self->endingtest($child->{label}, $tag->{label});
		}
		#! TODO: else generate mismatched tag error
	}

	# --- grab text between last tag and EOF ---
	if ($self->{_depth} == 1) {
		$self->{text} =~ m/\G(.*)/gs;
		push @children, $1 if $1;  # push text as a child
	}

	# --- return parsed tree ---
	$self->{_depth}--;
	return $self->_buildTag($tag->{label}, $tag->{params}, @children);
}

#	_splitTag - Breaks the tag into a label and key/value pairs
sub _splitTag {
	my ($self, $text) = @_;

	# --- determine the tag type ---
	my $tag = $self->prehandler($text);
	unless (defined $tag) {
		$tag = {
			type  => 'beginning',
			label => '',
			class => 'normal',
		};

		SWITCH: {
			# --- self-ending tag ---
			($text =~ m|/>$|) && do { $tag->{type} = 'selfending'; last; };
			# --- ending tag ---
			($text =~ m|^</|) && do { $tag->{type} = 'ending'; last; };
	}	}

	# === process all other (not code or eval) tags ===
	# --- get the label ---
	$text =~ m|</?([^>\s/]+)\s*(?:/?>)?|g;
	$tag->{label} = $1 if $1;

	# --- load the regexs for grepping the tag ---
	my $pairregex = reTagPair();
	my $loneregex = reTagStandAlone();

	my $lastparam = 0;
	while (!$lastparam) {
		if ($text =~ m/$pairregex/gco) {

			# --- found a paired value ---
			my ($key, $value) = ($1, $+);
			$value =~ s/\\([`'"])/$1/gs;  # normalize escapes
			$self->_addTagParam($tag, $key, $value);

		} elsif ($text =~ m/$loneregex/gco) {

			# --- found a key with no value ---
			$self->_addTagParam($tag, $+, '');

		} else {

			# --- we've hit the last parameter ---
			$lastparam = 1;
	}	}

	return $tag;
}

#	_addTagParam - helps build the tag parameter list
sub _addTagParam {
	my ($self, $tag, $key, $value) = @_;

	if ($self->{ParamFormat} ne 'HASH') {
		push @{$tag->{params}}, $key, $value;
		return $tag->{params};
	}

	my $params = $tag->{params};
	if (exists $params->{$key} && defined $params->{$key}) {
		if (ref $params->{$key} eq 'ARRAY') {
			push @{$params->{$key}}, $value;
		} else {
			$params->{$key} = [ $params->{$key}, $value ];
		}
	} else {
	   $params->{$key} = $value;
	}

	$tag->{params} = $params;
}

# --- tag prehandler (see splitTag) ---
# --- prehandler stub ---
# incoming: tag text (< to >)
# returns: a tag hash or undef if not processed
# set $tag->{type} = 'raw' to stop name-value parsing
sub prehandler { return undef }
sub endingtest { return undef }

#	Intermediate tag structure
#
#	$tag = {
#		type  => beginning | ending | selfending | root
#		label => prefix:name
#		class => normal | code | eval | raw
#	};

# === RegExes Encapsulated ==================================================
sub reTagParser {
	return qr/\G
		(.*?) # text before tag ($1)
		(<  # tag ($2) opening brace
			(?:[^!].*?|!--.*?--)  # label or comment
			(?:"(?:[^"\\]*(?:\\.[^"\\]*)*)" # double quotes
			  |'(?:[^'\\]*(?:\\.[^'\\]*)*)' # single quotes
			  |`(?:[^`\\]*(?:\\.[^`\\]*)*)` # back quotes
			  |.*?                          # anything else
			)*?                             # repeatedly
		>)  # closing brace
	/sx;
}
sub reTagPair {
	return qr/\G
		([\S]+?)\s*=\s*              # get key and '='
		(?:"([^"\\]*(?:\\.[^"\\]*)*)" # doublequoted value
		  |'([^'\\]*(?:\\.[^'\\]*)*)' # singlequoted value
		  |(`[^`\\]*(?:\\.[^`\\]*)*`) # backquoted value (keep quotes)
		  |([^\s>]*)                  # unquoted value
		)\s*                          #    and the space afterward
	/sx;
}
sub reTagStandAlone {
	return qr/\G
		(?:([\w.-]+) # get key
		  |(`[^`]*`) #    or an eval
		)\s*
	/sx;
}

1;

=head1 NAME

iTools::XML::Parser - itools' base XML parser class

=head1 SYNOPSIS

  my $xml = new iTools::XML::Parser;
  $xml->parse(
    Text => $text
    XMLHandlers => { Init => \&init, Start => \&start,
      Char => \&char, End => \&end, Final => \&final },
  );

  sub init { ... }
  sub start { ... }
  sub char { ... }
  sub end { ... }
  sub final { ... }

=head1 DESCRIPTION

B<iTools::XML::Parser> is a pure-Perl, lightweight XML parser with no notable dependencies (I have Data::Dumper included for debugging, but that comes stock with Perl).
It is more than adequate for parsing XML, but is not entirely XML compliant (see the section on B<XML COMPLIANCE>).
Some of the non-compliant bits are feature extensions that you may want to use.

The API is modeled (lightly) after the B<XML::Parser::Expat> module.
I will likely add extensions in the future to make it pluggable for compatibility.
Either that or create an iTools::XML::Expat module.

=head1 METHODS

There are only two publicly accesible methods in this module, B<new>() and B<parse>().
They both take the same parameters (you can pass them in either).

=over 4

=item B<new>([B<Text> => $TEXT,] [B<XMLHandlers> => \%HANDLERS,] [B<Object> => $OBJECT,] [B<ParamFormat> => 'HASH'|'ARRAY',])

The constructor - returns the created object.
Do I need to say more?

=item B<parse>([B<Text> => $TEXT,] [B<XMLHandlers> => \%HANDLERS,] [B<Object> => $OBJECT,] [B<ParamFormat> => 'HASH'|'ARRAY',])

This method invokes the parser and calls handlers.
It returns B<undef> if parsing failed or if there was nothing to parse, or an abstract parsetree datastructure if successful.
The parsetree datastructure is not documented for API use, so if you want to see what's going on, use Data::Dumper on the return value.

=back

=head2 Named Parameters

The constructor (B<new>()) and the B<parse>() methods may both recieve take the same set of named parameters.
When implementing the class, you may choose to pass the required parameters to either.

=over 4

=item B<Text> => $TEXT

This is the B<Text> of the XML itself as one big string.

=item B<XMLHandlers> => \%HANDLERS

This is a hash reference to the XML parsing handlers.

For details on how the handlers are called, see the B<HANDLERS> section below.
For object method references, see the B<Object> parameter below.

=item B<Object> => $OBJECT

If the B<XMLHandlers> are references to an object's methods (rather than global C<sub>s or class methods), it is required that you pass the B<Object> to the parser.
Failing to do so may cause the processing to treat the methods as class methods or simply cause the whole thing to fail.

=item B<ParamFormat> => 'HASH'|'ARRAY'

This parameter has two potential values, B<HASH> or B<ARRAY>.
It changes how tag parameters are passed to the B<Start> handler.

If set to B<HASH>, it will send a hash of tag parameters to the B<Start> handler (as documented in the B<HANDLERS> section below).
If set to B<ARRAY> (or anything other than B<HASH>), it will pass an array of alternating keys and values.

The difference between the two is subtle, but important in the following conditions:

=over 4

=item B<Capturing Tag Parameters In Order>

In most cases the order of parameters defined in the tag is not significant.
There may be cases where you want to capture the tag parameters in order, so having them sent to you as a hash is not particularly useful as a hash in Perl has no order.

Setting B<ParamFormat> to B<ARRAY> will return the tag parameters as an array, thereby preserving the order that they were captured.

=item B<Using The Tag Parameter Duplication Feature>

If you are using the non-standard feature documented in B<XML COMPLIANCE, Tag Parameter Duplication>,
setting B<ParamFormat> to B<ARRAY> and trying to capture the parameters as a hash will cause unpredictable results.

=back

If this parameter is not given, it is set to a default value of B<HASH>.

=back

=head1 HANDLERS

The following is a list of handlers available to the B<iTools::XML::Parser> B<parse>() method.
If the B<Object> parameter was used in the constructor or the B<parse>() method, all handlers will recieve a reference to C<$self> as their first parameter.

=over 4

=item B<Init> <- [$SELF], $HEADER

This handler is called before the first tag (root tag) is procesed.
The B<HEADER> parameter is a string containing all text before the root tag - i.e. "<?xml version="1.0"?>".

=item B<Start> <- [$SELF], $TAGNAME, %PARAMS

Called when a starting tag is encountered.
For standalone tags (<foo />), this is called as if it were and empty paired tag (<foo></foo>).

The parameters passed to this handler are: B<TAGNAME>, a string containing the name of the tag; B<PARAMS> a hash of parameters for the tag.

It is possible to recieve the B<PARAMS> as an ordered array if B<ParamFormat> is set to B<ARRAY> when B<new>() or B<parse>() is called.
See B<METHODS, Named Parameters, ParamFormat> for details.

=item B<Char> <- [$SELF], $CONTENT

Called when character content is encountered inside of a tag.
The B<CONTENT> is passed to the handler as a string.

=item B<End> <- [$SELF], $TAGNAME

This handler is called at the end of a paired or standalone tag with the B<TAGNAME> as a parameter.

=item B<Final> <- [$SELF]

When all XML is parsed, the B<Final> handler is called.

=back

=head1 EXAMPLES

=head2 Extending The iTools::XML::Parser Object

The following sample code shows how to extend the ::Parser object into your own class:

  #!/usr/bin/perl -w
  use strict;
  my $xml = new Foo::XML;
  $xml->parse(Text => $text);

  # === extended parser object =============================
  package Foo::XML;
  use base 'iTools::XML::Parser';

  # --- parse method for the object ---
  sub parse {
    my $self = shift;
    my $ptree = $self->SUPER::parse(@_,
      XMLHandlers => { Init => \&init, Start => \&start,
        Char => \&char, End => \&end, Final => \&final },
      Object => $self,
    );
  }

  # --- handlers ---
  sub init { ... }
  sub start { ... }
  sub char { ... }
  sub end { ... }
  sub final { ... }

This example doesn't show what to do with the data received in the handlers 'cause I can't predict how you plan to use the class.
It's likely that you'd store the captured data in a structure under C<$self>, but that's only my presumption.

For a sample implementation, see B<iTools::XML::Simple>.

=head2 Using iTools::XML::Parser directly

The example below shows how you can use the B<iTools::XML::Parser> class without wrapping it in a child object:

  #!/usr/bin/perl -w
  use strict;
  my $xml = new iTools::XML::Parser;
  $xml->parse(
    Text => $text
    XMLHandlers => { Start => \&start, Char => \&char, End => \&end },
  );

  # --- handlers ---
  sub start { ... }
  sub char { ... }
  sub end { ... }

Note that his example doesn't use all available handlers.
This is not a restriction of the class, but rather demonstration that not all handlers are required to be defined.
B<iTools::XML::Parser> will simply not call any handlers that are not defined.

=head1 XML COMPLIANCE

The B<iTools::XML::Parser> class is not strictly compliant with the XML 1.0 or 1.1 specification.

The following is a list of known compliance issues (I call them 'features' ;):

=over 4

=item B<Tag Parameter Quoting>

Tag parameters can be quoted with single quotes ('), double quotes ("), backticks (`), or no quotes at all.
Single, double and no quotes all have the same effect, but backticks are treated a bit different:

  <foo bar1='cheers' bar2="shorty's" bar3=TheSwillow bar4=`cat hooters` />

will be sent to the B<Start> handler as:

  'foo', bar1 => "cheers", bar2 => "shorty's",
    bar3 => "TheSwillow", bar4 => "`cat hooters`"

Note that the B<bar4> parameter includes the backticks in the value.
This allows the implementation of special non-standard functions.
I occasionally use the backticks to indicate evaluated code or system commands, but you can do whatever.

Note that if you don't use the funky quoting mechanisms, this will have no affect on you.

=item B<Tag Parameter Duplication>

Another extension I added is the ability to have the same parameter twice in the same tag, lika sooo:

  <foo bar="cheers" bar="shorty's" />

This be sent to the B<Start> handler as:

  'foo', bar => [ "cheers", "shorty's" ]

Once again, if you don't use it, it won't affect you.

=item B<Valueless Tag Parameters>

This is a holdover from the original HTML parsing engine that this all originated from.
This bit of XML:

  <foo bar1="" bar2 />

is sent to the B<Start> handler as:

  'foo', bar1 => "", bar2 => ""

The parameters without values are translated to an empty string.

Yet again, if you don't use it, it won't affect you.

=item B<Tag Parameter Quoting Escapes>

XML requires that you escape quotes-in-quotes with &quot;, &apos; and the like.
B<iTools::XML::Parser> also allows standard bash-ish/perl-ish escapes.
For example, this will parse just fine:

  <foo bar="I go to, \"cheers\"" />

The B<Start> handler receives this as:

  'foo', bar => 'I go to, "cheers"'

It seems that I'm repeating my self rather often, but I must say it ... If you don't use it, it won't affect you.

=back

=head1 TODO

  - complete the XML COMPLIANCE section 'cause there's a bunch of
      stuff I'm not accounting for.
  - review the XML::Parser::Expat module and class API bits to make
      it more compatible (like a setHandlers method)
  - complete &foo; escape translation subs and docs

=head1 KNOWN ISSUES AND BUGS

  - There is a known issue where the code can barf for mismatched
      tags (bad XML)

=head1 REPORTING BUGS

Report bugs in the iTools' issue tracker at
L<https://github.com/iellenberger/itools/issues>

=head1 AUTHOR

Ingmar Ellenberger, Deepak Kumar

=head1 COPYRIGHT

Copyright (c) 2001-2012 by Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<https://github.com/iellenberger/itools/blob/master/LICENSE>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 SEE ALSO

iTools::XML::Simple(3)

=cut
