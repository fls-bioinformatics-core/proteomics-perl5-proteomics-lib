# $Id: $

# 
# Perl module for protein digestion
#
# Copyright Julian Selley
#

# POD documentation

=head1 NAME

Proteomics::Trypsin - Mimics Trypsin digestion of proteins

=head1 SYNOPSIS

  use Proteomics::Trypsin;
  my $seq = 'SGHKVRISTYSANRKST';
  my $trypsin = new Proteomics::Trypsin;
  my @peptides = $trypsin-E<gt>digest($seq);

=head1 DESCRIPTION

This module is designed to mimic trypsin digestion of protein sequences.

=head1 EXPORT

None.

=head1 SEE ALSO

L<Proteomics::DigestionEnzyme>

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


package Proteomics::Trypsin;
use 5.010000;
use strict;
use warnings;

use base qw(Proteomics::DigestionEnzyme);
our $VERSION = '1.00';

use Bio::Seq;
use Carp;

=head2 new

 Title:     new
 Usage:     my $digest_obj = Proteomics::Trypsin->new()
 Function:  currently this is a dummy function to create a new object of this
            class, but it may be adapted later to provide some functionality
 Returns:   a new Proteomics::DigestionEnzyme::Trypsin object
 Arguments: none

=cut
sub new {
  my $self = shift;
  my $class = ref $self || $self;

  return bless {}, $class;
}

=head2 digest

 Title:     digest
 Usage:     my @peptides = digest(Bio::Seq->new(-seq => 'SGHKVRISTYSANRKST'));
 Function:  returns a set of digested peptides when provided a protein sequence
 Returns:   an array of strings representing peptide sequences
 Arguments: a Bio::Seq object or a string of amino-acids (representing a
            protein)

=cut
sub digest {
  # get arguments
  my ($self, $sequence) = @_;
  # if only one argument supplied (i.e., we have been called statically)
  $sequence = $self if (not defined $sequence);
  # exit if no sequence provided
  carp "called without a sequence" if (not defined $sequence);
  # convert the Bio::Seq (if provided) to just the straight sequence string
  $sequence = $sequence->seq if (ref $sequence eq 'Bio::Seq');
  # exit if the sequence is zero length
  carp "sequence is empty" if ($sequence eq "");

  # digest sequence
  my @peptides = split /(?<=[KR])(?=[^P])/, $sequence;

  # return the digested peptides
  return @peptides;
}


1;
__END__
