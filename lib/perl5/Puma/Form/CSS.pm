package Puma::Form::CSS;

use strict;
use warnings;

sub style {
	print qq[<style type="text/css">];
	css();
	print qq[<\\style>\n];
}

sub css {
	print "
	a.checkbox {
		text-decoration: none;
	}\n";
}

1;
