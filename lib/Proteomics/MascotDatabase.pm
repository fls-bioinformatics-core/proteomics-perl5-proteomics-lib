# $Id: $

##
## Perl module for inputing data into Mascot database (version 2.0)
##
## Copyright Julian Selley
##

# POD documentation

=head1 NAME

Proteomics::MascotDatabase - Provides connection to the database and means to
                             add data to the database

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
our $VERSION = '2.01';  # to connect to version 2.0 of the database

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

  # if there is a connection already specified, use that, otherwise create the
  # connection to the database based on parameters
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

  my $sql_get_modification = "SELECT * FROM `modification` WHERE <ARGUMENTS> LIMIT 1";
  my $mod = undef;

  # check mods stored in object
  return $this->{_modifications}->[$args{'Identifier'}]
    if (defined $args{'Identifier'} && defined $this->{_modifications}->[$args{'Identifier'}]);
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

=head2 insert_pep

 Title:     insert_pep
 Usage:     $db_obj->insert_pep(...);
 Function:  inserts the information for a peptide into the database
 Returns:   the pep_id from the database
 Arguments: the columns and values to be inserted

=cut
sub insert_pep {
  my $this  = shift;
  my $search_id = $this->last_inserted_search_id();
  my %args = @_;

  my $sql_check_pep_exists     = "SELECT * FROM `pep` WHERE `search_id` = ? AND `rank` = ? AND " .
                                 "`exp_mz` = ? AND `exp_z` = ? AND `calc_mr` = ? AND " .
                                 "`delta` = ? AND `score` = ? AND `expect` = ? AND " .
                                 "`seq` = ? AND `num_match` = ? AND `scan_title` = ?";
  my $sql_insert_pep           = "INSERT INTO `pep` SET <ARGUMENTS>";
  my $sql_update_pep           = "UPDATE `pep` SET <ARGUMENTS> WHERE `id` = ?";
  my $sql_insert_prot_has_pep  = "INSERT INTO `prot_has_pep` SET " . 
                                 "`search_id` = <SID>, `prot_id` = <PID>, " . 
                                 "`pep_id` = <PPID>";
  my $sql_check_query_exists   = "SELECT `id` FROM `query` WHERE `search_id` = ? AND `query_number` = ?";
  my $sql_check_query_has_pep_exists = "SELECT * FROM `query_has_pep` " . 
                                       "WHERE `search_id` = <SID> AND " .
                                       "`query_id` = <QID> AND " .
                                       "`pep_id` = <PPID>";
  my $sql_check_pep_has_modification = "SELECT * FROM `pep_has_modification` " .
                                       "WHERE `pep_id` = ? AND `modification_id` = ? AND " .
                                       "`position` = ?";
  my $sql_insert_query         = "INSERT INTO `query` SET `search_id` = ?, `query_number` = ?";
  my $sql_insert_query_has_pep = "INSERT INTO `query_has_pep` SET " .
                                "`search_id` = <SID>, `query_id` = <QID>, " .
                                "`pep_id` = <PPID>";
  my $sql_insert_pep_has_modification = "INSERT INTO `pep_has_modification` " .
                                        "SET `pep_id` = ?, " .
                                        "`modification_id` = ?, " .
                                        "`position` = ?";

  # collate arguments
  my $collated_arguments_str  = "";
  my @collated_arguments_vals = ();
  # update pep information if the pep is already present in the database
  my $update_pep = 0;
  my $update_pep_row = undef;
  my $sh = $this->{_conn}->prepare($sql_check_pep_exists);
  my $success = $sh->execute($search_id,
                             $args{'rank'} || $args{'pep_rank'}, 
                             $args{'exp_mz'} || $args{'pep_exp_mz'}, 
                             $args{'exp_z'} || $args{'pep_exp_z'},
                             $args{'calc_mr'} || $args{'pep_calc_mr'},
                             $args{'delta'} || $args{'pep_delta'},
                             $args{'score'} || $args{'pep_score'},
                             $args{'expect'} || $args{'pep_expect'},
                             $args{'seq'} || $args{'pep_seq'}, 
                             $args{'num_match'} || $args{'pep_num_match'},
                             $args{'scan_title'} || $args{'pep_scan_title'});
  if (defined $success && $success != 0 && $sh->rows > 0) {
    $update_pep = 1;
    $update_pep_row = $sh->fetchrow_hashref;
  }

  my @arg_keys = keys %args;
  for (my $ai = 0; $ai < @arg_keys; $ai++) {
    next if ($arg_keys[$ai] eq "pep_query" || $arg_keys[$ai] =~ /^pep_var_mod/ || $args{$arg_keys[$ai]} eq "" || $arg_keys[$ai] eq "DONT_INSERT_PROT_HAS_PEP");
    my $key = $arg_keys[$ai];
    next if (! defined $args{$key} || $args{$key} eq "" || ($update_pep && defined $update_pep_row->{$key} && $update_pep_row->{$key} eq $args{$key}));
    $key =~ s/^pep_//;
    $collated_arguments_str .= "`" . $key . "` = ?, ";
    push @collated_arguments_vals, $args{$arg_keys[$ai]};
  }
#  $collated_arguments_str =~ s/, $//;
  $collated_arguments_str .= "`search_id` = ?";
  push @collated_arguments_vals, $search_id;
  push @collated_arguments_vals, $update_pep_row->{'id'} if ($update_pep);

  # determine correct SQL and put in arguments
  my $sql_pep = ($update_pep) ? $sql_update_pep : $sql_insert_pep;
  $sql_pep =~ s/<ARGUMENTS>/$collated_arguments_str/;

  # execute SQL
  $sh = $this->{_conn}->prepare($sql_pep);
  if ($update_pep && defined $update_pep_row->{'scan_title'} && $update_pep_row->{'scan_title'} ne $args{'pep_scan_title'}) { print STDERR "\nupdating peptide: $update_pep_row->{'id'}\nprev_scan_title: $update_pep_row->{'scan_title'}, new_scan_title: $args{'pep_scan_title'}\nsql: $sql_pep\nargs: @collated_arguments_vals\n\n"; }
  $success = $sh->execute(@collated_arguments_vals);
  if (defined $success && $success != 0) {
    if ($update_pep) {
      $this->{'_last_inserted_pep_id'} = $update_pep_row->{'id'};
    } else {
      $this->{'_last_inserted_pep_id'} = $this->{_conn}->last_insert_id(undef, undef, 'pep', 'id');
    }
  } else {
    carp "WARNING: failed to insert pep to database ($this->{_conn}->errstr)";
  }

#  my $search_id = $this->last_inserted_search_id();
  my $prot_id   = $this->last_inserted_prot_id();
  my $pep_id    = $this->last_inserted_pep_id();
  if (! defined $args{'DONT_INSERT_PROT_HAS_PEP'}) {
    # insert information regarding the protein->peptide link
    $sql_insert_prot_has_pep =~ s/<SID>/$search_id/;
    $sql_insert_prot_has_pep =~ s/<PID>/$prot_id/;
    $sql_insert_prot_has_pep =~ s/<PPID>/$pep_id/;
    if (! $update_pep) {
      $sh = $this->{_conn}->prepare($sql_insert_prot_has_pep);
      $success = $sh->execute();
      if (! defined $success || $success == 0) {
        carp "WARNING: failed to insert prot_has_pep to database ($this->{_conn}->errstr)";
      }
    }
  }

  # insert modification positions (if they exist)
  if (defined $args{'pep_var_mod_pos'} && $args{'pep_var_mod_pos'} ne "") {
    my $shc = $this->{_conn}->prepare($sql_check_pep_has_modification);
    $sh = $this->{_conn}->prepare($sql_insert_pep_has_modification);
    my @mod_pos = split //, $args{'pep_var_mod_pos'};
    my $offset = 0;
    for (my $mpi = 0; $mpi < @mod_pos; $mpi++) {
      next if ($mod_pos[$mpi] =~ /^[0-9]$/ && $mod_pos[$mpi] == 0);
      if ($mod_pos[$mpi] eq '.') {
        $offset++;
        next;
      }
      my $mod = $this->get_modification(Identifier => $mod_pos[$mpi]);
      # see if the mod already documented
      $success = $shc->execute($pep_id, $mod->{'DBID'}, $mpi - $offset);
      # if it isn't, then store it
      if ((! defined $success || $success == 0) && defined $shc->rows && $shc->rows == 0) {
        $success = $sh->execute($pep_id, $mod->{'DBID'}, $mpi - $offset);
        if (! defined $success || $success == 0) {
          carp "WARNING: failed to insert pep_has_modification to database (" . DBI::errstr . ")";
        }
      }
    }
  }

  # check whether the query exists
  $sh = $this->{_conn}->prepare($sql_check_query_exists);
  $success = $sh->execute($search_id, $args{'pep_query'});
  if (! defined $success || $success == 0) {
    # insert the base of the query
    $sh = $this->{_conn}->prepare($sql_insert_query);
    $success = $sh->execute($search_id, $args{'pep_query'});
    if (! defined $success || $success == 0) {
      carp "WARNING: failed to insert query to database (" . DBI::errstr . ")";
    }
    $this->{'_last_inserted_query_id'} = $this->{_conn}->last_insert_id(undef, undef, 'query', 'id');
  } else {
    my $row = $sh->fetchrow_hashref;
    $this->{'last_inserted_query_id'} = $row->{'id'};
  }

  # check whether the link exists
  $sql_check_query_has_pep_exists =~ s/<SID>/$search_id/g;
  $sql_check_query_has_pep_exists =~ s/<QID>/$this->{'_last_inserted_query_id'}/g;
  $sql_check_query_has_pep_exists =~ s/<PPID>/$pep_id/g;
  $sh = $this->{_conn}->prepare($sql_check_query_has_pep_exists);
  $success = $sh->execute();
  if (! defined $success || $success == 0 || $sh->rows == 0) {
    # insert link from query to pep
    $sql_insert_query_has_pep =~ s/<SID>/$search_id/g;
    $sql_insert_query_has_pep =~ s/<QID>/$this->{'_last_inserted_query_id'}/g;
    $sql_insert_query_has_pep =~ s/<PPID>/$pep_id/g;
    $sh = $this->{_conn}->prepare($sql_insert_query_has_pep);
    $success = $sh->execute();
    if (! defined $success || $success == 0) {
      carp "WARNING: failed to insert query_has_pep to database (" . DBI::errstr . ")";
    }
  }

  return $this->{'_last_inserted_pep_id'};
}

=head2 insert_prot

 Title:     insert_prot
 Usage:     $db_obj->insert_prot(...);
 Function:  inserts the information for a protein into the database
 Returns:   the prot_id from the database
 Arguments: the columns and values to be inserted

=cut
sub insert_prot {
  my $this  = shift;
  my %args = @_;

  my $sql_insert_prot       = "INSERT INTO `prot` SET `search_id` = " .
                              $this->{'_last_inserted_search_id'} . ", <ARGUMENTS>";
  my $sql_update_prot       = "UPDATE `prot` SET <ARGUMENTS> WHERE `id` = ? " .
                              "AND `search_id` = " . $this->{'_last_inserted_search_id'};
  my $sql_check_prot_exists = "SELECT `id` FROM `prot` WHERE `id` = ?";

  my $update_prot = 0;

  # check for an id in the arguments supplied, and check it is in the database
  # before commiting to updating the database rather than inserting
  if (defined $args{'id'} && $args{'id'} != 0 && $args{'id'} =~ /^[0-9]+$/) {
    my $sh = $this->{_conn}->prepare($sql_check_prot_exists);
    $sh->execute($args{'id'});
    $update_prot = 1 if ($sh->rows > 0);
  }

  # collate arguments
  my $collated_arguments_str  = "";
  my @collated_arguments_vals = ();
  my @arg_keys = keys %args;
  for (my $ai = 0; $ai < @arg_keys; $ai++) {
    my $key = $arg_keys[$ai];
    $key =~ s/^prot_//;
    $collated_arguments_str .= "`" . $key . "` = ?, ";
    push @collated_arguments_vals, $args{$arg_keys[$ai]};
  }
  $collated_arguments_str =~ s/, $//;

  # determine correct SQL and put in arguments
  my $sql_prot = ($update_prot) ? $sql_update_prot : $sql_insert_prot;
  $sql_prot =~ s/<ARGUMENTS>/$collated_arguments_str/;

  # execute SQL
  my $sh = $this->{_conn}->prepare($sql_prot);
  my $success = $sh->execute(@collated_arguments_vals);
  if (defined $success && $success != 0) {
    $this->{'_last_inserted_prot_id'} = $this->{_conn}->last_insert_id(undef, undef, 'prot', 'id');
  } else {
    carp "WARNING: failed to insert prot to database ($this->{_conn}->errstr)";
  }

  return $this->{'_last_inserted_prot_id'};
}

=head2 insert_query

 Title:     insert_query
 Usage:     $db_obj->insert_query(...);
 Function:  inserts the information for a query into the database
 Returns:   the query_id from the database
 Arguments: the columns and values to be inserted

=cut
sub insert_query {
  my $this  = shift;
  my $search_id = $this->last_inserted_search_id();
  my %args = @_;

  my $sql_insert_query       = "INSERT INTO `query` SET <ARGUMENTS>";
  my $sql_update_query       = "UPDATE `query` SET <ARGUMENTS> WHERE `search_id` = ? AND `query_number` = ?";
  my $sql_check_query_exists = "SELECT * FROM `query` WHERE `search_id` = ? AND `query_number` = ?";
#  my $sql_insert_ion         = "INSERT INTO `ions1` SET `query_id` = ?, `moverz` = ?, `intensity` = ?, `charge` = ?";
#  my $sql_update_ion         = "UPDATE `ions1` SET `query_id` = ?, `moverz` = ?, `intensity` = ?, `charge` = ?`";  ## BAD SQL ##
#  my $sql_check_ion_exists   = "SELECT `id` FROM `ions1` WHERE `query_id` = ? AND `moverz` = ? AND `intensity` = ? LIMIT 1";

  my $update_query = 0;
  my $update_query_row = undef;
  my $q_id = undef;

  # check for an id in the arguments supplied, and check it is in the database
  # before commiting to updating the database rather than inserting
  if (defined $args{'query_number'} && $args{'query_number'} =~ /^[0-9]+$/) {
    my $sh = $this->{_conn}->prepare($sql_check_query_exists);
    $sh->execute($search_id, $args{'query_number'});
    if ($sh->rows > 0) {
      $update_query = 1;
      $update_query_row = $sh->fetchrow_hashref;
      $q_id = $update_query_row->{'id'};
    }
  }

  # collate arguments
  my $collated_arguments_str  = "";
  my @collated_arguments_vals = ();
  my %pep_collated_arguments  = ();
  my @arg_keys = keys %args;
  for (my $ai = 0; $ai < @arg_keys; $ai++) {
    my $key = $arg_keys[$ai];
    $key =~ tr/[A-Z]/[a-z]/;
    $key =~ s/\s+//g;
#    next if ($key =~ /^stringions/);
    next if ($update_query && $key =~ /^query_number$/);
    next if (defined $args{$arg_keys[$ai]} && $args{$arg_keys[$ai]} eq "");
    $args{$arg_keys[$ai]} =~ s/^([0-9]+)(\-)$/$2$1/ if ($key =~ /^charge$/);
    $args{$arg_keys[$ai]} =~ s/^([0-9])\+$/$1/ if ($key =~ /^charge$/);
    if ($key =~ /^pep_/) {
      $pep_collated_arguments{$key} = $args{$arg_keys[$ai]};
      if ($key =~ /^pep_scan_title$/ && ! defined $args{'StringTitle'} && $collated_arguments_str !~ /stringtitle/) {
        $collated_arguments_str .= "`stringtitle` = ?, ";
        push @collated_arguments_vals, $args{$arg_keys[$ai]};
      }
    } else {
      $collated_arguments_str .= "`" . $key . "` = ?, ";
      push @collated_arguments_vals, $args{$arg_keys[$ai]};
    }
  }
  $collated_arguments_str     =~ s/, $//;
  if ($update_query) {
    push @collated_arguments_vals, $search_id;
    push @collated_arguments_vals, $args{'query_number'};
  } else {
    $collated_arguments_str .= ", `search_id` = ?";
    push @collated_arguments_vals, $search_id;
  }
  $pep_collated_arguments{'pep_query'} = $args{'query_number'};

  # determine correct SQL and put in arguments
  my $sql_query = ($update_query) ? $sql_update_query : $sql_insert_query;
  $sql_query =~ s/<ARGUMENTS>/$collated_arguments_str/;

  if ($collated_arguments_str ne "" && @collated_arguments_vals > 0) {
    # execute SQL
    my $query_id = 0;
    my $sh = $this->{_conn}->prepare($sql_query);
    my $success = $sh->execute(@collated_arguments_vals);
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

#    # insert string ions
#    my @ions1 = split /,/, $args{'StringIons1'};
#    my $sh_ions_select = $this->{_conn}->prepare($sql_check_ion_exists);
#    for (my $ii = 0; $ii < @ions1; $ii++) {
#      my ($moverz, $intensity, $charge) = split /:/, $ions1[$ii];
#
#      # check whether query in database or, whether need to insert it
#      my $update_ions = 0;
#      my $selected_ion = undef;
#      if ($update_query) {
#        $success = $sh_ions_select->execute($query_id, $moverz, $intensity);
#        if (defined $success && $success != 0 && $sh_ions_select->rows > 0) {
#          $update_ions = 1;
#          $selected_ion = $sh_ions_select->fetchrow_hashref;
#          next if ($moverz == $selected_ion->{'moverz'} && $intensity == $selected_ion->{'intensity'} && $query_id == $selected_ion->{'query_id'} && $charge == $selected_ion->{'charge'});
#        }
#      }
#
#      my $sql_ion = ($update_ions) ? $sql_update_ion : $sql_insert_ion;
#      my $sh_ion = $this->{_conn}->prepare($sql_ion);
#      $charge = 'NULL' if (! defined $charge || $charge eq "");
#      print STDERR "sql: $sql_ion, args: $query_id $moverz, $intensity, $charge\n";
#      $success = $sh_ion->execute($query_id, $moverz, $intensity, $charge);  ## PROBLEM HERE ##
#      carp "WARNING: failed to insert ion to database (" . DBI::errstr . ")"
#        if (! defined $success || $success == 0);
#    }
#
  }

  my $insert_pep = $this->insert_pep(%pep_collated_arguments, DONT_INSERT_PROT_HAS_PEP => 0)
    if (defined $args{'pep_rank'} && $args{'pep_rank'} =~ /^[0-9]+$/);

  return $this->{'_last_inserted_query_id'};
}

=head2 insert_search

 Title:     insert_search
 Usage:     $db_obj->insert_search(...);
 Function:  inserts a search into the database
 Returns:   the search_id from the database
 Arguments: the columns and values to be inserted

=cut
sub insert_search {
  my $this  = shift;
  my %args = @_;

  my $sql_insert_search       = "INSERT INTO `search` SET <ARGUMENTS>";
  my $sql_update_search       = "UPDATE `search` SET <ARGUMENTS> WHERE `id` = ?";
  my $sql_check_search_exists = "SELECT `id` FROM `search` WHERE `id` = ?";

  my $update_search = 0;

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
