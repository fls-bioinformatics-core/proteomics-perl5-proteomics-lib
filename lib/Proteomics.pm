# $Id: $

# 
# Perl module for protein digestion
#
# Copyright Julian Selley
#

# POD documentation

=head1 NAME

Proteomics - Perl extension for experimental proteomics

=head1 SYNOPSIS

  use Proteomics;

=head1 DESCRIPTION

This module contains a series of calls to other libraries to
experimental proteomics.

=head1 EXPORT

N/A

=back

=head1 SEE ALSO

L<Proteomics::AminoAcidProperties>
L<Proteomics::Trypsin>
L<Proteomics::Utils>

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


package Proteomics;
use 5.010000;
use strict;
use warnings;

use base qw(Exporter);
our $VERSION = '1.00';


use Proteomics::AminoAcidProperties qw(:all);
use Proteomics::MascotDatabase;
use Proteomics::Trypsin;
use Proteomics::Utils qw(:all);


1;
__END__
