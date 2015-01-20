package iTools::Term::ANSI;
use base qw( Exporter );
$VERSION = "0.01";

@EXPORT_OK = qw(
	color colored cpush cpop
);

use Term::ANSIColor qw(:constants);
use Time::HiRes qw( usleep );

use strict;
use warnings;

# === Class Variables =======================================================

# --- ANSI conversion for output sequences ---
# sequence name => printf parsable ANSI code
our $OUT = {
	clear  => "\e[H\e[2J",
	moveto => "\e[\%d;\%dH",
};

# --- ANSI conversion for input sequences --
# escape sequence => key name
our $IN = {
	# --- keypad ---
	"\e[A"  => 'up',     "\e[B"  => 'down',
	"\e[C"  => 'right',  "\e[D"  => 'left',
	"\eOF"  => 'end',    "\eOH"  => 'home',
	"\e[2~" => 'insert', "\e[3~" => 'delete',
	"\e[5~" => 'pageup', "\e[6~" => 'pagedown',
	# --- function keys ---
	"\eOP"     => 'f1',  "\eOQ"     => 'f2',  "\eOR"     => 'f3',  "\eOS"     => 'f4',
	"\e[15~"   => 'f5',  "\e[17~"   => 'f6',  "\e[18~"   => 'f7',  "\e[19~"   => 'f8',
	"\e[20~"   => 'f9',  "\e[21~"   => 'f10', "\e[23~"   => 'f11', "\e[24~"   => 'f12',
	"\eO2P"    => 'f13', "\eO2Q"    => 'f14', "\eO2R"    => 'f15', "\eO2S"    => 'f16',
	"\e[15;2~" => 'f17', "\e[17;2~" => 'f18', "\e[18;2~" => 'f19', "\e[19;2~" => 'f20',
	"\e[20;2~" => 'f21', "\e[21;2~" => 'f22', "\e[23;2~" => 'f23', "\e[24;2~" => 'f24',

	"\eO5P"    => 'cf1',  "\eO5Q"    => 'cf2',  "\eO5R"    => 'cf3',  "\eO5S"    => 'cf4',
	"\e[15;5~" => 'cf5',  "\e[17;5~" => 'cf6',  "\e[18;5~" => 'cf7',  "\e[19;5~" => 'cf8',
	"\e[20;5~" => 'cf9',  "\e[21;5~" => 'cf10', "\e[23;5~" => 'cf11', "\e[24;5~" => 'cf12',
	"\eO6P"    => 'cf13', "\eO6Q"    => 'cf14', "\eO6R"    => 'cf15', "\eO6S"    => 'cf16',
	"\e[15;6~" => 'cf17', "\e[17;6~" => 'cf18', "\e[18;6~" => 'cf19', "\e[19;6~" => 'cf20',
	"\e[20;6~" => 'cf21', "\e[21;6~" => 'cf22', "\e[23;6~" => 'cf23', "\e[24;6~" => 'cf24',

	# --- other stuff ---
	"\e[Z" => 'backtab',
};

# --- ordinal names for ANSI codes ---
# ANSI code => [ 2/3-char name, short name, long name ]
our $ORD = {
	0   => [ 'nul', 'null',      'null' ],
	1   => [ 'soh', 'soh',       'start of header' ],
	2   => [ 'stx', 'stx',       'start of text' ],
	3   => [ 'etx', 'etx',       'end of text' ],
	4   => [ 'eot', 'eot',       'end of transmission' ],
	5   => [ 'enq', 'enq',       'enquire' ],
	6   => [ 'ack', 'ack',       'acknowledge' ],
	7   => [ 'bel', 'bell',      'bell' ],
	8   => [ 'bs',  'backspace', 'backspace' ],
	9   => [ 'ht',  'tab',       'horizontal tab' ],
	10  => [ 'lf',  'linefeed',  'linefeed' ],
	11  => [ 'vt',  'vtab',      'vertical tab' ],
	12  => [ 'ff',  'formfeed',  'form feed' ],
	13  => [ 'cr',  'return',    'carriage return' ],
	14  => [ 'so',  'so',        'shift out' ],
	15  => [ 'si',  'si',        'shift in' ],
	16  => [ 'dle', 'dle',       'data link escape' ],
	17  => [ 'dc1', 'dc1',       'device control 1' ],
	18  => [ 'dc2', 'dc2',       'device control 2' ],
	19  => [ 'dc3', 'dc3',       'device control 3' ],
	20  => [ 'dc4', 'dc4',       'device control 4' ],
	21  => [ 'nak', 'nak',       'negative acknowledge' ],
	22  => [ 'syn', 'sync',      'synchronous idle' ],
	23  => [ 'stb', 'etb',       'end of transmission block' ],
	24  => [ 'can', 'cancel',    'cancel previous word/char' ],
	25  => [ 'em',  'em',        'end of medium' ],
	26  => [ 'sub', 'sub',       'substitute' ],
	27  => [ 'esc', 'esc',       'escape' ],
	28  => [ 'fs',  'fs',        'file separator' ],
	29  => [ 'gs',  'gs',        'group separator' ],
	30  => [ 'rs',  'rs',        'record separator' ],
	31  => [ 'us',  'us',        'unit separator' ],
	32  => [ 'sp',  'space',     'space' ],
	127 => [ 'del', 'delete',    'delete' ],
};

# --- color management ---
our $COLORED = 1;
our @COLORSTACK;
our $colormap = {
	# --- colors ---
	'r' => RED,     'R' => BOLD . RED,     'hr' => ON_RED,
	'g' => GREEN,   'G' => BOLD . GREEN,   'hg' => ON_GREEN,
	'b' => BLUE,    'B' => BOLD . BLUE,    'hb' => ON_BLUE,
	'c' => CYAN,    'C' => BOLD . CYAN,    'hc' => ON_CYAN,
	'm' => MAGENTA, 'M' => BOLD . MAGENTA, 'hm' => ON_MAGENTA,
	'y' => YELLOW,  'Y' => BOLD . YELLOW,  'hy' => ON_YELLOW,
	'k' => BLACK,   'K' => BOLD . BLACK,   'hk' => ON_BLACK,
	'w' => WHITE,   'W' => BOLD . WHITE,   'hw' => ON_WHITE,

	# --- effects ---
	'*' => BOLD,  '_' => UNDERLINE, 'v' => REVERSE,
	':' => BLINK, '-' => CONCEALED, 'd' => DARK,
	'x' => RESET,
};

# === Constructor and Destructor ============================================
sub new {
	my $self = bless {}, ref($_[0]) || $_[0];

	# --- non-blocking/non-buffered reads ---
	use Fcntl qw(F_GETFL F_SETFL O_NONBLOCK);
	my $flags = fcntl(*STDIN, F_GETFL, 0);
	fcntl(*STDIN, F_SETFL, $flags | O_NONBLOCK);
	system "stty cbreak -echo";

	# --- catch <ctrl-c> ---
	$SIG{INT} = \&iTools::Term::ANSI::reaper;

	# --- other stuff ---
	$self->{keybuffer} = [];
	$self->{ordinals} = 2;    # used to determins which element of $ORD

	return $self;
}

# --- tty cleanup ---
sub DESTROY { shift->cleanExit }
sub cleanExit { system "stty -cbreak echo"; exit 0 }

# --- signal reaper ---
sub reaper {
	my $signal = shift;
	print "signal $signal caught - cleaning up and exiting\n";
	iTools::Term::ANSI::cleanExit();
}

# === Class Accessors =======================================================
# --- enable/diasable colors ---
sub colored { defined $_[0] ? $COLORED = $_[0] || 0 : $COLORED || 0 }

# === TTY I/O ===============================================================

# --- input ---
sub in {
	my ($self, $mode) = (shift, shift || -1);

	# --- read key, return if undef or not escape ---
	my $key = $self->readkey($mode);
	return undef unless defined $key;
	return $self->ordinal($key) unless $key && $key eq "\e";

	# --- read in remainder of keys in the buffer ---
	usleep 50000;  # sleep .05s to buffer chars
	while (defined (my $morekey = $self->readkey)) {
		$key .= $morekey;
		# --- return the key name if it matches ---
		return $IN->{$key} if exists $IN->{$key};
	};

	# --- no escape sequence found; add keys to buffer and return first key ---
	push @{$self->{keybuffer}}, split(//, $key);
	return $self->ordinal($self->readkey);
}
sub readkey {
	my ($self, $mode) = (shift, shift || -1);
	return shift @{$self->{keybuffer}} if @{$self->{keybuffer}};
	return getc;
}

# --- output ---
sub out { print shift->sout(@_) }
sub sout {
	my ($self, $cmd, @args) = @_;
	return "error: no such command '$cmd'" unless exists $OUT->{$cmd};
	return sprintf $OUT->{$cmd}, @args;
}

# === Private Methods =======================================================
# --- convert character ordinal name ---
sub ordinal {
	my ($self, $char) = @_;
	return $char if $self->{ordinals} == 0 || $self->{ordinals} > 3;

	# --- return ordinal name ---
	# use $self->{ordinals} to determine which version to return ---
	return $ORD->{ord($char)}->[$self->{ordinals} - 1]
		if exists $ORD->{ord($char)};

	# --- no ordinal?  just return the char ---
	return $char;
}

# --- get TTY size ---
sub size {
	my $stty = `stty -a`;
	my $cols = ($stty =~ /columns (\d+);/ms)[0] || 80;
	my $rows = ($stty =~ /rows (\d+);/ms)[0] || 24;
	return $rows, $cols;
}

# === Color Exports =========================================================
# --- non-stack vesion of color ---
sub color {
	my ($codes, $text) = @_;

	# --- do nothing if colors not enabled ---
	return defined $text ? $text : ''
		unless $COLORED;

	# ---  return the ANSI sequence if no text given---
	return $COLORED ? _colorCode2ANSI($codes) : ''
		unless defined $text;

	# --- return the colored text ---
	return cpush($codes) . $text . cpop();
}

# --- push color onto stack ---
sub cpush {
	my $ansi = '';

	foreach my $codes (@_) {
		# --- push codes on stack --
		unshift @COLORSTACK, $codes;
		$ansi .= $COLORED ? _colorCode2ANSI($codes) : '';
	}

	# --- return ANSI if enabled ---
	return $ansi;
}

# --- pop a color off the stack ---
sub cpop {
	my $count = shift || 1;
	# --- return blank if stack is empty ---
	return '' unless @COLORSTACK;

	# --- reset and revert to previous color ---
	map { shift @COLORSTACK } ( 1 .. $count );
	my $ansi = RESET . _colorCode2ANSI($COLORSTACK[0]);

	# --- return color if enabled ---
	return colored() ? $ansi : '';
}

# --- private method for converting color codes to ANSI ---
sub _colorCode2ANSI {
	my $codes = shift;
	# --- no code, return empty string ---
	return '' unless $codes;

	# --- declare a few vars ---
	my $ansi = '';
	my $highlight = 0;

	# --- convert code(s) to ANSI ---
	foreach my $code (split '', $codes) {

		# --- highlighting requested ---
		if (lc $code eq 'h') { $highlight++; next }
		# --- set 2-char code for highlights ---
		if ($highlight) { $code = lc "h$code"; $highlight = 0 }

		# --- set the color or effect ---
		$ansi .= $colormap->{$code}
			if exists $colormap->{$code};
	}

	return $ansi;
}

1;

=head1 NAME

iTools::Term::ANSI - iTools terminal effects library

=head1 SYNOPSIS

 use iTools::Term::ANSI;

 print cpush('R') ."RED!". cpop;

=head1 DESCRIPTION

Provides functions and methods for ANSI terminal sequences.

=head1 EXPORTS

All color functions are automatically exported.

=over 4

=item B<colored>({true/false})

Enables or disables color codes.
If set to a false value (0, '' or undef), all color functions will return
empty strings rather than the requested ANSI sequence.

=item B<color>(CODES)

Returns the ANSI code for colors and effects.
CODES is one or more of the following:

           -------- Code ---------
    Color  Normal  Bold  Highlight
    -----  ------  ----  ---------
    Red       r      R      hr
    Green     g      G      hg
    Blue      b      B      hb
    Cyan      c      C      hc
    Magenta   m      M      hm
    Yellow    y      Y      hy
    Black     k      K      hk
    White     w      W      hw

    Effect     Code
    ---------  --------------
    Bold       * (star)
    Underline  _ (underscore)
    Reverse    v
    Blink      : (colon)
    Concealed  - (dash)
    Dark       d
    Reset      x

Unrecognized characters are ignored.

=item B<cpush>(CODES)

Same as color() except that it pushes the CODES on a stack.
This, inconjunction with cpop() allows you to nest colors.

=item B<cpop>()

Pops a color code off the stack and returns the ANSI sequence to reset to that color.
If the stack is empty, it returns an ANSI reset code.

=back

=head1 TODO, KNOWN ISSUES AND BUGS

=over 4

=item B<Document and test TermIO functionality>

The code from iTab::Term has been imported into this class for backward compatibility.
Document and test these functions.

=back

=head1 REPORTING BUGS

Report bugs in the iTools' issue tracker at
L<https://github.com/iellenberger/itools/issues>

=head1 AUTHOR

Written by Ingmar Ellenberger.

=head1 COPYRIGHT

Copyright (c) 2001-2012 by Ingmar Ellenberger and distributed under The Artistic License.
For the text the license, see L<https://github.com/iellenberger/itools/blob/master/LICENSE>
or read the F<LICENSE> in the root of the iTools distribution.

=head1 SEE ALSO

Term::ANSIColor(3pm)

=cut
