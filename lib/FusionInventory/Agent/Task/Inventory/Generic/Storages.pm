package FusionInventory::Agent::Task::Inventory::Generic::Storages;

use strict;
use warnings;

sub isEnabled {
    my (%params) = @_;
    return 0 if $params{no_category}->{storage};
    return 1;
}

sub doInventory {}

1;
