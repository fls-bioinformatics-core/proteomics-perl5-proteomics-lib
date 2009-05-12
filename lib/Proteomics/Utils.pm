# $Id: $

# 
# Perl module containing a collection of Proteomic utility functions
#
# Copyright Julian Selley
#

# POD documentation

=head1 NAME

Proteomics::Utils - Perl extension containing a number of utility
                    functions relating to Proteomics

=head1 SYNOPSIS

  use Proteomics::Utils qw(:all);
  my $seq = 'SGHKVRISTYSANRKST';
  my $mmass = calculateMonoisotopicMass($seq);

=head1 DESCRIPTION

This module contains a series of procedures useful for Proteomics
data analysis.

=head1 EXPORT

=over

=item double calculateAverageMass(string)

=item double calculateMonoisotopicMass(string)

=back

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


package Proteomics::Utils;
use 5.010000;
use strict;
use warnings;

use base qw(Exporter);
our $VERSION = '1.00';
our %EXPORT_TAGS = ( 'all' => [ qw(
  &calculateAverageMass
  &calculateMonoisotopicMass
) ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

use Bio::Seq;
use Carp;
use Proteomics::AminoAcidProperties qw(:all);

=head2 calculateAverageMass

 Title:     calculateAverageMass
 Usage:     my $amass = calculateAverageMass(Bio::Seq->new(-seq => 'SGHKVRISTYSANRKST'));
 Function:  calculates the average mass of the supplied protein sequence
 Returns:   the average mass of the supplied protein sequence
 Arguments: a Bio::Seq object or a string of amino-acids (representing a
            protein)

=cut
sub calculateAverageMass {
  # get arguments
  my ($self, $sequence) =@_;
  # if only one argument supplied (i.e., we have been called statically)
  $sequence = $self if (not defined $sequence);
  # exit if no sequence provided
  carp "called without a sequence" if (not defined $sequence);
  # convert the Bio::Seq (if provided) to just the straight sequence string
  $sequence = $sequence->seq if (ref $sequence eq 'Bio::Seq');
  # exit if the sequence is zero length
  carp "sequence is empty" if ($sequence eq "");

  my $mass = 0.00;

  # calculate the mass of the sequence
  foreach my $aa (split //, $sequence) {
    $mass += getAverageMass($aa);
  }

  # return the mass
  return $mass;
}

=head2 calculateMonoisotopicMass

 Title:     calculateMonoisotopicMass
 Usage:     my $amass = calculateMonoisotopicMass(Bio::Seq->new(-seq => 'SGHKVRISTYSANRKST'));
 Function:  calculates the monoisotopic mass of the supplied protein sequence
 Returns:   the monoisotopic mass of the supplied protein sequence
 Arguments: a Bio::Seq object or a string of amino-acids (representing a
            protein)

=cut
sub calculateMonoisotopicMass {
  # get arguments
  my ($self, $sequence) =@_;
  # if only one argument supplied (i.e., we have been called statically)
  $sequence = $self if (not defined $sequence);
  # exit if no sequence provided
  carp "called without a sequence" if (not defined $sequence);
  # convert the Bio::Seq (if provided) to just the straight sequence string
  $sequence = $sequence->seq if (ref $sequence eq 'Bio::Seq');
  # exit if the sequence is zero length
  carp "sequence is empty" if ($sequence eq "");

  my $mass = 0.00;

  # calculate the mass of the sequence
  foreach my $aa (split //, $sequence) {
    $mass += getMonoisotopicMass($aa);
  }

  # return the mass
  return $mass;
}


1;
__END__
