##
## Perl module for inputing data into Mascot database (version 2.0)
##
## Copyright Julian Selley
##

# POD documentation

=head1 NAME

Proteomics::MascotDatabase - Provides connection to the database and means
                             to add data to the database

=head1 SYNOPSIS

  use Proteomics::MascotDatabase;
  my $db = new Proteomics::MascotDatabase();
  my $protein_id = $db->insert_prot(hit_num => 1, acc => "IPI000000", ...);

=head1 DESCRIPTION



=head1 EXPORT

None.

=head1 SEE ALSO

None.

=head1 AUTHOR

Julian Selley, E<lt>j.selley@manchester.ac.ukE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Julian Selley

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal methods are usually preceded with a _

=cut


package Proteomics::MascotDatabase;

use 5.010000;
use strict;
use warnings;

use base qw(Exporter);
our $VERSION = '3.01';  # to connect to version 3.0 of the database

## IMPORT
use AppConfig qw(:expand);
use Carp;
use Data::Dumper;
use DBI;

=head2 DESTROY

 Title:     DESTROY
 Usage:
 Function:
 Returns:   
 Arguments: 

=cut
sub DESTROY {
  my $this = shift;
  $this->SUPER::DESTROY if $this->can("SUPER::DESTROY");

  $this->disconnect;
}

=head2 new

 Title:     new
 Usage:
 Function:
 Returns:   
 Arguments: 

=cut
sub new {
  my $this  = shift;
  my $class = ref $this || $this;

  my %args = (
    user       => 'mascot_rw',
    password   => 'iX4ors79rnzH',
    driver     => 'mysql',
    name       => 'mascot',
    host       => 'localhost',
    options    => { RaiseError => 0, AutoCommit => 1 },
    config_fn  => undef,
    connection => undef,
    @_
  );
  $this = {};

  # set defaults on some object variables
  $this->{'_last_inserted_search_id'} = 0;
  $this->{'_last_inserted_prot_id'}   = 0;
  $this->{'_last_inserted_pep_id'}    = 0;
  $this->{'_last_inserted_query_id'}  = 0;
  $this->{'_modifications'}            = [];

  # if there is a configuration file specified, load that information
  if (defined $args{'config_fn'}) {
    my $config = new AppConfig({ GLOBAL => { EXPAND => EXPAND_VAR, } });
    $config->define('database_driver=s');
    $config->define('database_name=s');
    $config->define('database_host=s');
    $config->define('database_user=s');
    $config->define('database_password=s');
    $config->define('database_options=s');
    $args{'driver'}   = $config->database_driver;
    $args{'name'}     = $config->database_name;
    $args{'host'}     = $config->database_host;
    $args{'user'}     = $config->database_user;
    $args{'password'} = $config->database_password;
    $args{'options'}  = $config->database_options;
  }

  # if there is a connection already specified, use that, otherwise create
  # the connection to the database based on parameters
  if (defined $args{'connection'} && ref $args{'connection'} eq "DBI::db") {
    $this->{_conn} = $args{'connection'};
  } else {
    $this->{_conn} = DBI->connect("DBI:" . $args{'driver'} . ":" .
                                  $args{'name'} . ":" .
                                  $args{'host'},
                                  $args{'user'},
                                  $args{'password'},
                                  { eval($args{'options'}) }) or
      carp "ERROR: Connection to database unsuccessful: " . $DBI::errstr;
  }

  # get list of tables (and views)
  my @tbls = $this->{'_conn'}->tables();
  $this->{'_tables'} = \@tbls;
  # get columns for each table
  foreach my $tbl (@tbls) {
    $tbl =~ s/\`//g;
    $tbl =~ s/.+\.(.+)/$1/;
    my @cols = ();
    my @req_cols = ();
    my $sh = $this->{'_conn'}->prepare('DESC ' . $tbl);
    $sh->execute();
    while (my $col = $sh->fetchrow_hashref()) {
      push @cols, $col->{'Field'};
      push @req_cols, $col->{'Field'}
        if ($col->{'Null'} =~ m/^NO$/i && 
            ! defined $col->{'Default'} && 
            ! defined $col->{'Extra'});
    }
    # store the columns
    $this->{'_table_struct'}->{$tbl} = \@cols;
    $this->{'_table_required_columns'}->{$tbl} = \@req_cols;
  }

  return bless $this, $class;
}

=head2 disconnect

 Title:     disconnect
 Usage:     $db_obj->disconnect();
 Function:  disconnects the database connection
 Returns:   n/a
 Arguments: none

=cut
sub disconnect {
  my $this = shift;

  if (defined $this->{_conn}) {
    $this->{_conn}->disconnect();
    $this->{_conn} = undef;
  }

  return 0;
}

=head2 get_modification

 Title:     get_modification
 Usage:     my $mod_id = $db_obj->get_modification(...);
 Function:  get a modification from the database
 Returns:   the modification row as a ref to a hash from the database
 Arguments: the columns and values to be define what modification_id to get

=cut
sub get_modification {
  my $this = shift;
  my %args = @_;

  my $sql_get_modification = "SELECT * FROM `modification` " .
                             "WHERE <ARGUMENTS> LIMIT 1";
  my $mod = undef;

  # check mods stored in object
  return $this->{_modifications}->[$args{'Identifier'}]
    if (defined $args{'Identifier'} && 
        defined $this->{_modifications}->[$args{'Identifier'}]);
  if (defined $args{'Name'}) {
    for (my $mi = 0; $mi < @{$this->{_modifications}}; $mi++) {
      return $this->{_modifications}->[$mi]
        if ($this->{_modifications}->[$mi]->{'Name'} eq $args{'Name'});
    }
  }

  # collate arguments
  my $collated_arguments_str  = "";
  my @collated_arguments_vals = ();
  my @arg_keys = keys %args;
  for (my $ai = 0; $ai < @arg_keys; $ai++) {
    my $key = $arg_keys[$ai];
    $key =~ tr/[A-Z]/[a-z]/;
    $key =~ s/\s+//g;
    $key =~ s/\(.+\)//g;
    next if ($key eq "identifier");
    $collated_arguments_str .= "`" . $key . "` = ?, ";
    push @collated_arguments_vals, $args{$arg_keys[$ai]};
  }
  $collated_arguments_str =~ s/, $//;

  # substitute in arguments to narrow search
  $sql_get_modification =~ s/<ARGUMENTS>/$collated_arguments_str/;

  # execute SQL
  my $sh = $this->{_conn}->prepare($sql_get_modification);
  my $success = $sh->execute(@collated_arguments_vals);
  if (defined $success && $success != 0 && $sh->rows > 0) {
    $mod = $sh->fetchrow_hashref();
  }

  return $mod;
}

=head2 insert_modification

 Title:     insert_modification
 Usage:     my $mod_id = $db_obj->insert_modification(name => 'Phospho (ST)', delta => -78.0);
 Function:  insert a modification into the database
 Returns:   the last inserted modification_id from the database
 Arguments: the columns and values to be inserted

=cut
sub insert_modification {
  my $this = shift;
  my %args = @_;

  # return if the required arguments aren't supplied
  my @req_cols = (@{$this->{'_table_required_columns'}->{'modification'}});
  foreach my $req_col (@req_cols) {
    carp "WARNING: required arguments not supplied to insert_modification ($req_col)"
      if (! defined $args{$req_col});
  }

  # sql statements
  my $sql_get_modification    = "SELECT * FROM `modification` WHERE <ARGUMENTS> LIMIT 1";
  my $sql_insert_modification = "INSERT INTO `modification` SET <ARGUMENTS>";

  # collate arguments
  my $collated_arguments_str  = "";
  my @collated_arguments_vals = ();
  my @arg_keys = keys %args;
  for (my $ai = 0; $ai < @arg_keys; $ai++) {
    my $key = $arg_keys[$ai];
    $key =~ tr/[A-Z]/[a-z]/;
    $key =~ s/\s+//g;
    $key =~ s/\(.+\)//g;
    next if ($key eq "identifier");
    $collated_arguments_str .= "`" . $key . "` = ?, ";
    push @collated_arguments_vals, $args{$arg_keys[$ai]};
  }
  $collated_arguments_str =~ s/, $//;

  # determine correct SQL and put in arguments
  $sql_get_modification    =~ s/<ARGUMENTS>/$collated_arguments_str/;
  $sql_get_modification    =~ s/,/ AND/g;
  $sql_insert_modification =~ s/<ARGUMENTS>/$collated_arguments_str/;

  # execute get SQL to check whether it already exists
  my $sh = $this->{_conn}->prepare($sql_get_modification);
  my $success = $sh->execute(@collated_arguments_vals);
  if (defined $success && $success != 0 && $sh->rows != 0) {
    my $mod = $sh->fetchrow_hashref;
    $mod->{'DBID'} = $mod->{'id'};
    $mod->{'Identifier'} = $args{'Identifier'};
    $this->{_modifications}->[$args{'Identifier'}] = $mod;
    return $mod->{'id'};
  }

  # otherwise execute insert SQL
  $sh = $this->{_conn}->prepare($sql_insert_modification);
  $success = $sh->execute(@collated_arguments_vals);
  if (defined $success && $success != 0) {
    $this->{'_last_inserted_modification_id'} = 
      $this->{_conn}->last_insert_id(undef, undef, 'modification', 'id');
    $args{'DBID'} = $this->{'_last_inserted_modification_id'};
    if (defined $args{'Identifier'}) {
      $this->{_modifications}->[$args{'Identifier'}] = \%args;
    } else {
      push @{$this->{_modifications}}, \%args;
    }
  } else {
    carp "WARNING: failed to insert modification to database (" . DBI::errstr . ")";
  }

  return $this->{'_last_inserted_modificaiton_id'};
}

=head2 

 Title:     insert_pep
 Usage:     
 Function:  
 Returns:   
 Arguments: 

=cut
sub insert_pep {
  my $this = shift;
  my $search_id = $this->last_inserted_search_id();
  my $prot_id   = $this->last_inserted_prot_id();
  my $pep_id    = undef;
  my $query_id  = undef;
  my %args = @_;

  # return if the required arguments aren't supplied
  my @req_cols = (@{$this->{'_table_required_columns'}->{'pep'}}, @{$this->{'_table_required_columns'}->{'prot_has_pep'}});
  foreach my $req_col (@req_cols) {
    carp "WARNING: required arguments not supplied to insert_pep ($req_col)"
      if (! defined $args{$req_col} && ! defined $args{'pep_' . $req_col});
  }

  # sql statements
  my $sql_insert_pep = "INSERT INTO `pep` SET `search_id` = ?, <ARGUMENTS>";
  my $sql_insert_prot_has_pep = "INSERT INTO `prot_has_pep` SET `search_id` = $search_id, `prot_id` = $prot_id, `pep_id` = ?, <ARGUMENTS>";
  my $sql_insert_pep_has_modification = "INSERT INTO `pep_has_modification` SET `pep_id` = ?, `modification_id` = ?, `position` = ?";
  my $sql_insert_query = "INSERT INTO `query` SET `search_id` = $search_id, `query_number` = ?";
  my $sql_insert_query_has_pep = "INSERT INTO `query_has_pep` SET `search_id` = $search_id, `query_id` = ?, `pep_id` = ?, <ARGUMENTS>";

  # argument variables
  my $pep_collated_args_str  = "";
  my @pep_collated_args_vals = ();
  my $php_collated_args_str  = "";
  my @php_collated_args_vals = ();
  my @phm_collated_args_vals = ();
  my @q_collated_args_vals   = ();
  my $qhp_collated_args_str  = "";
  my @qhp_collated_args_vals = ();

  # sort out arguments to correct tables
  my @args_keys = keys %args;
  for (my $ai = 0; $ai < @args_keys; $ai++) {
    my $key = $args_keys[$ai];
    $key =~ s/^pep_//;
    if ($key ~~ @{$this->{'_table_struct'}->{'pep'}}) {
      $pep_collated_args_str .= "`" . $key . "` = ?, ";
      push @pep_collated_args_vals, $args{$args_keys[$ai]};
    } elsif ($key ~~ @{$this->{'_table_struct'}->{'prot_has_pep'}}) {
      $php_collated_args_str .= "`" . $key . "` = ?, ";
      push @php_collated_args_vals, $args{$args_keys[$ai]};
    } elsif ($key ~~ @{$this->{'_table_struct'}->{'query_has_pep'}}) {
      $qhp_collated_args_str .= "`" . $key . "` = ?, ";
      push @qhp_collated_args_vals, $args{$args_keys[$ai]};
    } elsif ($key =~ /query/) {
      push @q_collated_args_vals, $args{$args_keys[$ai]};
    } elsif ($key =~ /var_mod_pos/ && defined $args{$args_keys[$ai]} && 
             $args{$args_keys[$ai]} ne "") {
      my @mod_pos = split //, $args{$args_keys[$ai]};
      my $offset = 0;
      for (my $mpi = 0; $mpi < @mod_pos; $mpi++) {
        next if ($mod_pos[$mpi] =~ /^[0-9]$/ && $mod_pos[$mpi] == 0);
        if ($mod_pos[$mpi] eq '.') {
          $offset++;
          next;
        }
        my $mod = $this->get_modification(Identifier => $mod_pos[$mpi]);
        my @phm_vals = ();
        push @phm_vals, $mod->{'DBID'};
        push @phm_vals, $mpi - $offset;
        push @phm_collated_args_vals, \@phm_vals;
      }
    }
  }
  $pep_collated_args_str =~ s/, $//;
  $php_collated_args_str =~ s/, $//;
  $qhp_collated_args_str =~ s/, $//;

  # insert peptide info
  $sql_insert_pep =~ s/<ARGUMENTS>/$pep_collated_args_str/;
  my $sh = $this->{'_conn'}->prepare($sql_insert_pep);
  my $success = $sh->execute($search_id, @pep_collated_args_vals);
  if ($success) {
    $pep_id = $this->{'_conn'}->last_insert_id(undef, undef, 'pep', 'id');
    $this->{'_last_inserted_pep_id'} = $pep_id;
  } else {
    my $sql_get_duplicate_entry = 
      "SELECT `id` FROM `pep` " .
      " WHERE `search_id` = ? " .
      "  AND `scan_title` = ? " .
      "  AND `exp_mz` = ? " .
      "  AND `seq` = ? " .
      "  AND `score` = ? " .
      "LIMIT 1";
      $sh = $this->{'_conn'}->prepare($sql_get_duplicate_entry);
      $success = $sh->execute($search_id, 
        $args{'scan_title'} || $args{'pep_scan_title'},
        $args{'exp_mz'} || $args{'pep_exp_mz'},
        $args{'seq'} || $args{'pep_seq'},
        $args{'score'} || $args{'pep_score'});
      if ($success) {
        $pep_id = $sh->fetchrow_hashref->{'id'};
        $this->{'_last_inserted_pep_id'} = $pep_id;
      } else {
        carp "WARNING: failed to insert pep ($this->{'_conn'}->errstr)";
      }
  }

  if (defined caller(1) && 
      (caller(1))[3] ne "Proteomics::MascotDatabase::insert_query") {
    # insert link to protein
    $sql_insert_prot_has_pep =~ s/<ARGUMENTS>/$php_collated_args_str/;
    $sh = $this->{'_conn'}->prepare($sql_insert_prot_has_pep);
    $sh->execute($pep_id, @php_collated_args_vals);

    # insert query
    if (@q_collated_args_vals != 0) {
      $sh = $this->{'_conn'}->prepare($sql_insert_query);
      $success = $sh->execute(@q_collated_args_vals);
    }
  }

  # insert query has pep link
  if ($success) {
    if (defined caller(1) && (caller(1))[3] eq "Proteomics::MascotDatabase::insert_query") {
      $query_id = $this->last_inserted_query_id();
    } else {
      $query_id = $this->{'_conn'}->last_insert_id(undef, undef, 'query', 'id');
      $this->{'_last_inserted_query_id'} = $query_id;
    }
    if ($query_id != 0 && $pep_id != 0) {
      $sql_insert_query_has_pep =~ s/<ARGUMENTS>/$qhp_collated_args_str/;
      $sh = $this->{'_conn'}->prepare($sql_insert_query_has_pep);
      $sh->execute($query_id, $pep_id, @qhp_collated_args_vals);
    }
  }

  # insert link to modification (if present)
  if (defined $args{'pep_var_mod_pos'} || defined $args{'var_mod_pos'}) {
    $sh = $this->{'_conn'}->prepare($sql_insert_pep_has_modification);
    for (my $phmcavi = 0; $phmcavi < @phm_collated_args_vals; $phmcavi++) {
      $sh->execute($pep_id, @{$phm_collated_args_vals[$phmcavi]});
    }
  }

  return $this->{'_last_inserted_pep_id'};
}

=head2 

 Title:     insert_prot
 Usage:     
 Function:  
 Returns:   
 Arguments: 

=cut
sub insert_prot {
  my $this = shift;
  my $search_id = $this->last_inserted_search_id();
  my $prot_id   = undef;
  my %args = @_;

  # return if the required arguments aren't supplied
  my @req_cols = (@{$this->{'_table_required_columns'}->{'prot'}});
  foreach my $req_col (@req_cols) {
    carp "WARNING: required arguments not supplied to insert_prot ($req_col)"
      if (! defined $args{$req_col} && ! defined $args{'prot_' . $req_col});
  }

  # sql statements
  my $sql_insert_prot = "INSERT INTO `prot` SET `search_id` = ?, <ARGUMENTS>";

  # argument variables
  my $prot_collated_args_str  = "";
  my @prot_collated_args_vals = ();
  my @args_keys = keys %args;
  for (my $ai = 0; $ai < @args_keys; $ai++) {
    my $key = $args_keys[$ai];
    $key =~ s/^prot_//;
    $prot_collated_args_str .= "`" . $key . "` = ?, ";
    push @prot_collated_args_vals, $args{$args_keys[$ai]};
  }
  $prot_collated_args_str =~ s/, $//;

  # execute the SQL and insert the protein
  $sql_insert_prot =~ s/<ARGUMENTS>/$prot_collated_args_str/;
  my $sh = $this->{'_conn'}->prepare($sql_insert_prot);
  my $success = $sh->execute($search_id, @prot_collated_args_vals);
  if (defined $success && $success != 0) {
    $prot_id = $this->{'_conn'}->last_insert_id(undef, undef, 'prot', 'id');
    $this->{'_last_inserted_prot_id'} = $prot_id;
  }

  return $this->{'_last_inserted_prot_id'};
}

=head2 

 Title:     insert_query
 Usage:     
 Function:  
 Returns:   
 Arguments: 

=cut
sub insert_query {
  my $this = shift;
  my $search_id = $this->last_inserted_search_id();
  my %args = @_;

  # return if the required arguments aren't supplied
  my @req_cols = (@{$this->{'_table_required_columns'}->{'query'}});
  foreach my $req_col (@req_cols) {
    carp "WARNING: required arguments not supplied to insert_query ($req_col)"
      if (! defined $args{$req_col});
  }

  # sql statements
#  my $sql_insert_query         = "INSERT INTO `query` SET `search_id` = $search_id, <ARGUMENTS>";
  my $sql_insert_query         = "INSERT INTO `query` SET <ARGUMENTS>";
  my $sql_update_query         = "UPDATE `query` SET <ARGUMENTS> WHERE `search_id` = $search_id AND `query_number` = ?";
  my $sql_check_query_exists   = "SELECT * FROM `query` WHERE `search_id` = ? AND `query_number` = ?";
#  my $sql_insert_query_has_pep = "INSERT INTO `query_has_pep` SET `search_id` = $search_id, `query_id` = ?, `pep_id` = ?, <ARGUMENTS>";
  my $update_query = 0;
  my $update_query_row = undef;
  my $q_id = undef;

  # check for an id in the arguments supplied, and check it is in the database
  # before commiting to updating the database rather than inserting
  if (defined $args{'query_number'} && $args{'query_number'} =~ /^[0-9]+$/) {
    my $sh = $this->{'_conn'}->prepare($sql_check_query_exists);
    $sh->execute($search_id, $args{'query_number'});
    if ($sh->rows > 0) {
      $update_query = 1;
      $update_query_row = $sh->fetchrow_hashref;
      $q_id = $update_query_row->{'id'};
    }
  }

  # argument variables
  my $q_collated_args_str    = "";
  my @q_collated_args_vals   = ();
  my %pep_collated_args = ();
  my @args_keys = keys %args;
  for (my $ai = 0; $ai < @args_keys; $ai++) {
    my $key = $args_keys[$ai];
    $key =~ tr/[A-Z]/[a-z]/;
    $key =~ s/\s+//g;
    next if ($update_query && $key =~ /^query_number$/);
    next if (defined $args{$args_keys[$ai]} && $args{$args_keys[$ai]} eq "");
    $args{$args_keys[$ai]} =~ s/^([0-9]+)(\-)$/$2$1/ if ($key =~ /^charge$/);
    $args{$args_keys[$ai]} =~ s/^([0-9])\+$/$1/ if ($key =~ /^charge$/);
    if ($key =~ /^pep_/) {
      $pep_collated_args{$key} = $args{$args_keys[$ai]};
    } else {
      $q_collated_args_str .= "`" . $key . "` = ?, ";
      push @q_collated_args_vals, $args{$args_keys[$ai]};
    }
  }
  $q_collated_args_str =~ s/, $//;
  if ($update_query) {
    push @q_collated_args_vals, $args{'query_number'};
  } else {
    $q_collated_args_str .= ", `search_id` = ?";
    push @q_collated_args_vals, $search_id;
  }
  $pep_collated_args{'pep_query'} = $args{'query_number'};

  # determine correct SQL and put in arguments
  my $sql_query = ($update_query) ? $sql_update_query : $sql_insert_query;
  $sql_query =~ s/<ARGUMENTS>/$q_collated_args_str/;
  my $success;
  my $query_id = 0;

  if ($q_collated_args_str ne "" && @q_collated_args_vals > 0) {
    # execute SQL
    my $sh = $this->{_conn}->prepare($sql_query);
    $success = $sh->execute(@q_collated_args_vals);
    if (defined $success && $success != 0) {
      if ($update_query) {
        $this->{'_last_inserted_query_id'} = $q_id;
      } else {
        $this->{'_last_inserted_query_id'} = $this->{_conn}->last_insert_id(undef, undef, 'query', 'id');
      }
      $query_id = $this->{'_last_inserted_query_id'};
    } else {
      carp "WARNING: failed to insert query to database (" . DBI::errstr . ")";
    }
  }

  # insert pep info (if it exists)
  if (defined $args{'pep_rank'} && $args{'pep_rank'} =~ /^[0-9]+$/) {
    my $pep_id = $this->insert_pep(%pep_collated_args);
#    # insert query has pep link
#    my $sh = $this->{'_conn'}->prepare($sql_insert_query_has_pep);
#    $sh->execute($query_id, $pep_id);
  }

  return $this->{'_last_inserted_query_id'};
}

=head2 

 Title:     insert_search
 Usage:     
 Function:  
 Returns:   
 Arguments: 

=cut
sub insert_search {
  my $this = shift;
  my %args = @_;

  # return if the required arguments aren't supplied
  my @req_cols = (@{$this->{'_table_required_columns'}->{'search'}});
  foreach my $req_col (@req_cols) {
    carp "WARNING: required arguments not supplied to insert_search ($req_col)"
      if (! defined $args{$req_col});
  }

  # sql statements
  my $sql_insert_search       = "INSERT INTO `search` SET <ARGUMENTS>";
  my $sql_update_search       = "UPDATE `search` SET <ARGUMENTS> WHERE `id` = ?";
  my $sql_check_search_exists = "SELECT * FROM `search` WHERE `id` = ?";
  my $update_search = 0;
  my $update_search_row = undef;
  my $search_id = undef;

  # check for an id in the arguments supplied, and check it is in the database
  # before commiting to updating the database rather than inserting
  if (defined $args{'id'} && $args{'id'} != 0 && $args{'id'} =~ /^[0-9]+$/) {
    my $sh = $this->{_conn}->prepare($sql_check_search_exists);
    $sh->execute($args{'id'});
    $update_search = 1 if ($sh->rows > 0);
  }

  # collate arguments
  my $collated_arguments_str  = "";
  my @collated_arguments_vals = ();
  my @arg_keys = keys %args;
  for (my $ai = 0; $ai < @arg_keys; $ai++) {
    $collated_arguments_str .= "`" . $arg_keys[$ai] . "` = ?, ";
    push @collated_arguments_vals, $args{$arg_keys[$ai]};
  }
  $collated_arguments_str =~ s/, $//;
  push @collated_arguments_vals, $this->last_inserted_search_id if ($update_search);

  # determine correct SQL and put in arguments
  my $sql_search = ($update_search) ? $sql_update_search : $sql_insert_search;
  $sql_search =~ s/<ARGUMENTS>/$collated_arguments_str/;

  # execute SQL
  my $sh = $this->{_conn}->prepare($sql_search);
  my $success = $sh->execute(@collated_arguments_vals);
  if (defined $success && $success != 0 && ! $update_search) {
    $this->{'_last_inserted_search_id'} = $this->{_conn}->last_insert_id(undef, undef, 'search', 'id');
  } elsif (! defined $success || $success == 0) {
    carp "WARNING: failed to insert search to database ($this->{_conn}->errstr)";
  }

  return $this->{'_last_inserted_search_id'};
}

=head2 last_inserted_pep_id

 Title:     last_inserted_pep_id
 Usage:     my $pep_id = $db_obj->last_inserted_pep_id();
 Function:  the database id for the last inserted peptide
 Returns:   the last inserted pep_id from the database
 Arguments: none

=cut
sub last_inserted_pep_id {
  my $this = shift;

  return $this->{'_last_inserted_pep_id'};
}

=head2 last_inserted_prot_id

 Title:     last_inserted_prot_id
 Usage:     my $prot_id = $db_obj->last_inserted_prot_id();
 Function:  the database id for the last inserted protein
 Returns:   the last inserted prot_id from the database
 Arguments: none

=cut
sub last_inserted_prot_id {
  my $this = shift;

  return $this->{'_last_inserted_prot_id'};
}

=head2 last_inserted_query_id

 Title:     last_inserted_query_id
 Usage:     my $query_id = $db_obj->last_inserted_query_id();
 Function:  the database id for the last inserted query
 Returns:   the last inserted query_id from the database
 Arguments: none

=cut
sub last_inserted_query_id {
  my $this = shift;

  return $this->{'_last_inserted_query_id'};
}

=head2 last_inserted_search_id

 Title:     last_inserted_search_id
 Usage:     my $search_id = $db_obj->last_inserted_search_id();
 Function:  the database id for the last inserted search
 Returns:   the last inserted search_id from the database
 Arguments: none

=cut
sub last_inserted_search_id {
  my $this = shift;

  return $this->{'_last_inserted_search_id'};
}


1;
__END__
