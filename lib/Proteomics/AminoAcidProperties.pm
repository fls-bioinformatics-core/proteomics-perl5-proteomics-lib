# $Id: $

#
# Perl module containing the various properties of amino-acids
#
# Copyright Julian Selley
#

# POD documentation

=head1 NAME

AninoAcids - a module for looking up the properties of aminoacids

=head1 SYNOPSIS

use Proteomics::AminoAcidProperties qw(:all);

=head1 DESCRIPTION

This module contains information regarding amino-acids and their
properties.  It provides accessor methods, which are injected into
your code when you use the module as prescriped in the L<SYNOPSIS>.

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


package Proteomics::AminoAcidProperties;
use 5.010000;
use strict;
use warnings;

use base qw(Exporter);
our $VERSION = '1.00';
our %EXPORT_TAGS = ( 'all' => [ qw(
  &getAverageMass
  &getMonoisotopicMass
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

use Carp;

our %__average_mass = (
  'A' => 71.0779,
  'C' => 103.1429,
  'D' => 115.0874,
  'E' => 129.114,
  'F' => 147.1739,
  'G' => 57.0513,
  'H' => 137.1393,
  'I' => 113.1576,
  'K' => 128.1723,
  'L' => 113.1576,
  'M' => 131.1961,
  'N' => 114.1026,
  'P' => 97.1152,
  'Q' => 128.1292,
  'R' => 156.1857,
  'S' => 87.0773,
  'T' => 101.1039,
  'V' => 99.1311,
  'W' => 186.2099,
  'Y' => 163.1733,
);
our %__monoisotopic_mass = (
  'A' => 71.037114,
  'C' => 103.009185,
  'D' => 115.026943,
  'E' => 129.042593,
  'F' => 147.068414,
  'G' => 57.021464,
  'H' => 137.058912,
  'I' => 113.084064,
  'K' => 128.094963,
  'L' => 113.084064,
  'M' => 131.040485,
  'N' => 114.042927,
  'P' => 97.052764,
  'Q' => 128.058578,
  'R' => 156.101111,
  'S' => 87.032028,
  'T' => 101.047679,
  'V' => 99.068414,
  'W' => 186.079313,
  'Y' => 163.063329,
);

=head2 getAverageMass

 Title:     getAverageMass
 Usage:     my $amass = getAverageMass('A');
 Function:  returns the average mass of a given amino acid
 Returns:   a float relating to the average mass of the supplied amino acid
 Arguments: a char representing the single-letter-code of an amino acid

=cut
sub getAverageMass {
  # get arguments
  my ($self, $aa) = @_;
  # if only one argument supplied (i.e., we have been called statically)
  $aa = $self if (not defined $aa);
  # exit if no amino acid provided
  carp "called without an aminoacid" if (not defined $aa or $aa eq '');

  # return the average mass of the amino acid
  return $Proteomics::AminoAcidProperties::__average_mass{$aa};
}

=head2 getMonoisotopicMass

 Title:     getMonoisotopicMass
 Usage:     my $amass = getMonoisotopicMass('A');
 Function:  returns the monoisotopic mass of a given amino acid
 Returns:   a float relating to the monoisotopic mass of the supplied amino acid
 Arguments: a char representing the single-letter-code of an amino acid

=cut
sub getMonoisotopicMass {
  # get arguments
  my ($self, $aa) = @_;
  # if only one argument supplied (i.e., we have been called statically)
  $aa = $self if (not defined $aa);
  # exit if no amino acid provided
  carp "called without an aminoacid" if (not defined $aa or $aa eq '');

  # return the monoisotopic mass of the amino acid
  return $Proteomics::AminoAcidProperties::__monoisotopic_mass{$aa};
}


1;
__END__
