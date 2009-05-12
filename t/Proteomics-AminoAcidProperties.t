# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl Proteomics-AminoAcidProperties.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 8;
BEGIN { use_ok('Proteomics::AminoAcidProperties', ':all') };

#########################

# TEST check getAverageMass() function exported
ok(defined &getAverageMass, 'getAverageMass() exported');
# TEST check getMonoisotopicMass() function exported
ok(defined &getMonoisotopicMass, 'getMonoisotopicMass() exported');

# TEST check __average_mass not exported
ok(! defined %__average_mass, 'average_mass hash not exported');
# TEST check __monoisotopic_mass not exported
ok(! defined %__monoisotopic_mass, 'monoisotopic_mass hash not exported');

# TEST check average mass returns correct value
is(getAverageMass('A'), 71.0779, 'average mass Ala');
# TEST check monoisotopic mass returns correct value
is(getMonoisotopicMass('A'), 71.037114, 'monoisotopic mass Ala');
