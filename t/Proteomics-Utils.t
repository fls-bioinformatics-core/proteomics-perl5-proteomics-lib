# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as 
# `perl Proteomics-AminoAcidProperties.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 8;
BEGIN { use_ok('Bio::Seq') };
BEGIN { use_ok('Proteomics::Utils', ':all') };

#########################

# genuine sequence taken from SGD "YDR211W GCD6 SGDID:S000002619": first 120 res
our $protein = Bio::Seq->new
  (-seq         => "MAGKKGQKKSGLGNHGKNSDMDVEDRLQAVVLTDSYETRFMPLTAVKPRCLLPLANVPLI" .
                   "EYTLEFLAKAGVHEVFLICSSHANQINDYIENSKWNLPWSPFKITTIMSPEARCTGDVMR",
   -description => "YDR211W GCD6 SGDID:S000002619, Chr IV from 884725-886863, Verified ORF",
   -display_id  => "YDR211W",
   -accession_number => "S000002619",
   -alphabet    => 'protein');
our $protein_sequence_str = $protein->seq;

our $expected_protein_avg_mass  = 13421.3898;
our $expected_protein_mono_mass = 13412.792188;

# TEST check calculateAverageMass() function exported
ok(defined &calculateAverageMass, 'calculateAverageMass() exported');
# TEST check calculateMonoisotopicMass() function exported
ok(defined &calculateMonoisotopicMass, 'calculateMonoisotopicMass() exported');

# TEST calculate the average mass of the sequence, as a Bio::Seq
is(calculateAverageMass($protein), $expected_protein_avg_mass,
   'calculating the average mass of a protein (Bio::Seq)');
# TEST calculate the monoisotopic mass of the sequence, as a Bio::Seq
is(calculateMonoisotopicMass($protein), $expected_protein_mono_mass,
   'calculating the monoisotopic mass of a protein (Bio::Seq)');
# TEST calculate the average mass of the sequence, as a string
is(calculateAverageMass($protein_sequence_str), $expected_protein_avg_mass,
   'calculating the average mass of a protein (string)');
# TEST calculate the average mass of the sequence, as a string
is(calculateMonoisotopicMass($protein_sequence_str), $expected_protein_mono_mass,
   'calculating the monoisotopic mass of a protein (string)');
