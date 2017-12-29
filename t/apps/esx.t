#!/usr/bin/perl

use strict;
use warnings;
use lib 't/lib';

use English qw(-no_match_vars);
use Test::More;

use FusionInventory::Agent::Task::ESX;
use FusionInventory::Test::Utils;

plan tests => 7;

my ($out, $err, $rc);

($out, $err, $rc) = run_executable('fusioninventory-esx', '--help');
ok($rc == 0, '--help exit status');
is($err, '', '--help stderr');
like(
    $out,
    qr/^Usage:/,
    '--help stdout'
);

($out, $err, $rc) = run_executable(
    'fusioninventory-esx',
    '--host unknowndevice --user a --password a --directory /tmp'
);
like($err, qr/500\s\S/, 'Bad hostname');

($out, $err, $rc) = run_executable('fusioninventory-esx', '--version');
ok($rc == 0, '--version exit status');
is($err, '', '--version stderr');
like(
    $out,
    qr{fusioninventory-esx $FusionInventory::Agent::Task::ESX::VERSION},
    '--version stdout'
);
