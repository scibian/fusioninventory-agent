#!/usr/bin/perl

use strict;
use warnings;
use lib 't/lib';

use Test::Deep;
use Test::Exception;
use Test::More;
use Test::NoWarnings;

use FusionInventory::Test::Inventory;
use FusionInventory::Agent::Task::Inventory::Generic::Storages::HP;

my %slots_tests = (
    sample1 => [ 2 ],
    sample2 => [ 3, 0 ]
);

my %drives_tests = (
    sample1 => [ '2I:1:1', '2I:1:2' ],
    sample2 => [ '1I:1:1', '1I:1:2' ],
);

my %storage_tests = (
    sample1 => {
        NAME         => 'WDC WD740ADFD-00',
        FIRMWARE     => '21.07QR4',
        SERIALNUMBER => 'WD-WMANS1732855',
        TYPE         => 'disk',
        DISKSIZE     => '74300',
        DESCRIPTION  => 'SATA',
        MODEL        => 'WDC WD740ADFD-00',
        MANUFACTURER => 'Western Digital'
    },
    sample2 => {
        NAME         => 'Hitachi HUA72201',
        MODEL        => 'Hitachi HUA72201',
        FIRMWARE     => 'JP4OA3MA',
        DISKSIZE     => '1000000',
        MANUFACTURER => 'Hitachi',
        SERIALNUMBER => 'JPW9K0N02UPXHL',
        DESCRIPTION  => 'SATA',
        TYPE         => 'disk'
    }
);

plan tests =>
    (scalar keys %slots_tests)   +
    (scalar keys %drives_tests)  +
    (2 * scalar keys %storage_tests) +
    1;

my $inventory = FusionInventory::Test::Inventory->new();

foreach my $test (keys %slots_tests) {
    my $file  = "resources/generic/hpacucli/$test-slots";
    cmp_deeply(
        [ FusionInventory::Agent::Task::Inventory::Generic::Storages::HP::_getSlots(file => $file) ],
        $slots_tests{$test},
        "$test: slots extraction"
    );
}

foreach my $test (keys %drives_tests) {
    my $file  = "resources/generic/hpacucli/$test-drives";
    cmp_deeply(
        [ FusionInventory::Agent::Task::Inventory::Generic::Storages::HP::_getDrives(file => $file) ],
        $drives_tests{$test},
        "$test: drives extraction"
    );
}

foreach my $test (keys %storage_tests) {
    my $file  = "resources/generic/hpacucli/$test-storage";
    my $storage = FusionInventory::Agent::Task::Inventory::Generic::Storages::HP::_getStorage(file => $file);
    cmp_deeply(
        $storage,
        $storage_tests{$test},
        'storage extraction'
    );
    lives_ok {
        $inventory->addEntry(section => 'STORAGES', entry => $storage);
    } "$test: registering";
}
