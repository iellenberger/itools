package Puma::Core::RegEx;
use base Exporter;

@EXPORT_OK = qw( reTagParser reAttribute parseAttribute );

use Data::Dumper; $Data::Dumper::Indent = 1; # for debugging only

use strict;
use warnings;

# === RegEx Definitions =====================================================
# --- regex for parsing Puma tags out of a body of text---
sub reTagParser {
	my $labelrules = shift;

	# --- extended label rules ---
	$labelrules = $labelrules ? '(?:'. $labelrules .')' : '';

	# --- the regex ---
	return qr{
		\G    # start at end of last re search
		(.*?) # grab text before the tag ($1)

		# --- start matching tag ($2)---
		(	(?:<!--.*?-->      # match a comment or ...
			  |<:\S*\s.*?/>    # match a code/eval/special tag or ...
			  |</?             # opening brace and possible end tag
				(?:$labelrules) # label matching rules

				# --- test for quotes so we don't wrongly detect tag endings ---
				(?:"(?:[^"\\]*(?:\\.[^"\\]*)*)" # doublequoted string
				  |'(?:[^'\\]*(?:\\.[^'\\]*)*)' # singlequoted string
				  |`(?:[^`\\]*(?:\\.[^`\\]*)*)` # backquoted string
				  |.*?                          # anything else
				)*?                             # ... and do it repeatedly

				# --- end of tag match ---
				> # closing brace
		)	)
	}sx;
}

# --- regex for splitting tags attributes into their key and value components ---
sub reAttribute {
	return qr{
		\G                               # start at end of last re search
		((?:[\w.-]+                      # get key
			|`[^`\\]*(?:\\.[^`\\]*)*`     #    or a key eval
		))\s*                            # space afterward
		(?:=\s*                          # '='
			(?:"([^"\\]*(?:\\.[^"\\]*)*)" # doublequoted value
			  |'([^'\\]*(?:\\.[^'\\]*)*)' # singlequoted value
			  |(`[^`\\]*(?:\\.[^`\\]*)*`) # backquoted value (keep quotes)
			  |([^\s>]*)                  # unquoted value
			)
		)?\s*                            # space afterward
	}sx;
}

# === Exported Functions ====================================================
# --- implementation of reAttribute w/ quote cleanup ---
sub parseAttribute {
	my ($pair, $regex) = (shift, reAttribute());

	# --- run regex and get key ---
	my @matches = ($pair =~ m/$regex/);
	my $key = _unquote(shift @matches, '`');

	# --- get value ---
	my $value;
	CASE: {
		defined $matches[0] && do { $value = _unquote($matches[0], '"'); last };
		defined $matches[1] && do { $value = _unquote($matches[1], "'"); last };
		defined $matches[2] && do { $value = _unquote($matches[2], '`'); last };
		defined $matches[3] && do { $value = $matches[3]; last };
	};

	# --- return key and value ---
	return ($key, $value);
}
# --- local helper for parseAttribute ---
sub _unquote {
	my ($string, $quote) = @_;
	$string =~ s/\\$quote/$quote/g;
	return $string;
}

1;

=head1 NAME

Puma::Core::RegEx - regular expression repository for Puma

=head1 SYNOPSIS

 use Puma::Core::RegEx qw( reTagParser reAttribute parseAttribute );
 my $regex = reTagParser($rules);
 $regex = reAttribute();
 my ($key, $value) = parseAttribute('key="value"');

=head1 DESCRIPTION

The B<Puma::Core::RegEx> package returns precompiled, predefined regular expressions for Puma's core functions.
By placing many of the more complex regular expressions in this package, the code becomes much more readable.

=head1 EXPORTED FUNCTIONS

=over 4

=item B<reTagParser>([LABELRULES])

Returns the main regex for separating Puma's markup out of the data stream.
The parameter B<LABELRULES> defines additional rules that extend the regex to capture non-standard or proprietary tags.

The regex returns two values ($1 and $2): the text before the tag and the content of the tag itself.

=item B<reAttribute>()

Returns a regex that breaks a tag attribute into a B<key> ($1) and a B<value> (one of $2 through $5).
The return position of the B<value> depends on how it is quoted:

   $2 - double quotes (")
   $3 - single quotes (')
   $4 - backquotes (`)
   $5 - unquoted

Breaking up the regex matches like this allows you to differentiate the quoting mechanisms and parse them accordingly.

For single (') and double (") quotes, the quotes will be removed from the returned B<value>, but backquotes (`) will not be removed.

Both the B<key> and B<value> can be wrapped in backquotes (`).

Quotes within quotes may be escaped with a simple backslash (\), but the regex will not remove the backslashes, so you'll have to do that yourself.

All unfulfilled B<value> conditions will be set to B<undef>.
If the attribute has no B<value> (B<key> only), all values will be returned as B<undef>.

=item B<parseAttribute>(ATTRIBUTE)

This is a wrapper around the B<reAttribute> regex that returns a B<key> => B<value> pair for the given B<ATTRIBUTE>.
All backslash-escaped quotes will be unescaped.

=back

=head1 EXAMPLES

=head1 TODO

   - add documentation for comment and code/eval tag parsing
   - add unit test for code/evel tag parsing

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

strict(3pm), warnings(3pm) and Exporter(3pm) (stock Perl)

=head1 SEE ALSO

=cut
