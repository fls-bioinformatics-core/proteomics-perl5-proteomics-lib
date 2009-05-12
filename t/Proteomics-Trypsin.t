# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Proteomics-Trypsin.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 7;
BEGIN { use_ok('Bio::Seq') };
BEGIN { use_ok('Proteomics::Trypsin') };

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
our @digest = ();

# expected result of trypsin digest
our @expected_peptides_trypsinDigest = qw(MAGK K GQK K SGLGNHGK NSDMDVEDR 
  LQAVVLTDSYETR FMPLTAVKPR CLLPLANVPLIEYTLEFLAK AGVHEVFLICSSHANQINDYIENSK 
  WNLPWSPFK ITTIMSPEAR CTGDVMR);

# create an object
my $digest_obj = Proteomics::Trypsin->new();
# TEST new(): test the object created ok
ok(defined $digest_obj && ref $digest_obj eq 'Proteomics::Trypsin', 'new()');
# TEST digest_obj isa Proteomics::Trypsin object
isa_ok($digest_obj, 'Proteomics::Trypsin');
# TEST digest_obj implements Proteomics::DigestionEnzyme object
isa_ok($digest_obj, 'Proteomics::DigestionEnzyme');


# TEST trypsin digest from the Bio::Seq object: is the returned peptides as
#  expected for the Bio::Seq object
@digest = $digest_obj->digest($protein);
is_deeply(\@digest, \@expected_peptides_trypsinDigest,
          'trypsin digest from the Bio::Seq object');
@digest = ();  # reset digest

# TEST trypsin digest from sequence string: is the returned peptides
#  as expected
@digest = $digest_obj->digest($protein_sequence_str);
is_deeply(\@digest, \@expected_peptides_trypsinDigest,
          'trypsin digest from sequence string');
@digest = ();  # reset digest


