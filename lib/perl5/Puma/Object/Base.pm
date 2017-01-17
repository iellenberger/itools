package Puma::Object::Base;

use strict;
use warnings;

# === Class Methods =========================================================
sub objectType { 'Base' }

# === Constructor ===========================================================
sub new { bless {}, ref $_[0] || $_[0] }

1;

=head1 NAME

Puma::Object::Base - base class for Puma objects

=head1 SYNOPSIS

 use base Puma::Object::Base;
 sub objectType { 'SomeType' }

=head1 DESCRIPTION

This is the base class for all objects used in the Puma runtime, including applications, stateful objects and tags.

This class is intended as an abstract class, but it can be instantiated as a fully functional object (although I can't imagee why you'd want to).

=head1 METHODS

=over 4

=item B<new>()

This is a primitive constructor put im place to ensure that all subclasses have a constructor.
All it does is return the instantiated object.

=item $obj->B<objectType>() or

=item &CLASSNAME::B<objectType>()

Returns a string identifier indicating an object or class.
By default, the string returned is 'Base', but this method should be overridden by any subclasses.

=back

=head1 EXAMPLES

Here's an extract from Puma's base Tag object as an example of how this class is used:

  package Puma::Object::Tag;
  use base 'Puma::Object::Base';

  sub objectType { 'Tag' }

and then to instantiate and use the class:

  my $obj = new Puma::Object::Tag;
  print "Object is a Tag\n"
     if $obj->objectType eq 'Tag';

That's about it.
See the B<METHODS> section for more details.

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

B<Puma::Object::Base> requires the following modules usually distributed with Perl:

  strict(3pm) and warnings(3pm)

=head1 SEE ALSO

=cut
