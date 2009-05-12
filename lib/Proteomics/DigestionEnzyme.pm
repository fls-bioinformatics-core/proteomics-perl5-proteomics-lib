# $Id: $

# 
# Perl module for protein digestion
#
# Copyright Julian Selley
#

# POD documentation

=head1 NAME

Proteomics::DigestionEnzyme - Emulates a digestion enzyme

=head1 DESCRIPTION

This module is an abstract class that provides a function designed to
mimic the digestion enzyme.  Digestion enzyme classes extend this
class.

=head1 EXPORT

None.

=head1 SEE ALSO

No suggestions.

=head1 AUTHOR

Julian Selley, E<lt>j.selley@manchester.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Julian Selley

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


package Proteomics::DigestionEnzyme;
use 5.010000;
use strict;
use warnings;

use base qw(Class::Virtually::Abstract);   # this class is abstract
__PACKAGE__->virtual_methods(qw(digest));  # define the abstract methods
our $VERSION = '1.00';

use Bio::Seq;
use Carp;

=head2 C<digest>

 Title:     digest
 Usage:     _abstract function: no usage_
 Function:  should return a set of digested peptides when provided a protein
            sequence
 Returns:   an array of strings representing peptide sequences
 Arguments: a Bio::Seq object or a string of amino-acids (representing a
            protein)

=cut


1;
__END__
