#!/usr/bin/perl

use strict;
use warnings;
use lib 't/lib';

use English qw(-no_match_vars);
use File::Temp;
use Test::More;
use XML::TreePP;

use FusionInventory::Agent::Tools;
use FusionInventory::Test::Utils;

plan tests => 34;

my ($content, $out, $err, $rc);

($out, $err, $rc) = run_executable('fusioninventory-agent', '--help');
ok($rc == 0, '--help exit status');
is($err, '', '--help stderr');
like(
    $out,
    qr/^Usage:/,
    '--help stdout'
);

($out, $err, $rc) = run_executable('fusioninventory-agent', '--version');
ok($rc == 0, '--version exit status');
is($err, '', '--version stderr');
like(
    $out,
    qr/^FusionInventory Agent/,
    '--version stdout'
);

my $regconf = $OSNAME eq 'MSWin32' ? keys(%{FusionInventory::Test::Utils::openWin32Registry()}) : 0;

($out, $err, $rc) = run_executable('fusioninventory-agent', $regconf ? '--config none' : undef);
ok($rc == 1, 'no target exit status');
like(
    $err,
    qr/No target defined/,
    'no target stderr'
);
is($out, '', 'no target stdout');

($out, $err, $rc) = run_executable(
    'fusioninventory-agent',
    '--config none --conf-file /foo/bar'
);
ok($rc == 1, 'incompatible options exit status');
like(
    $err,
    qr/don't use --conf-file/,
    'incompatible options stderr'
);
is($out, '', 'incompatible options stdout');

my $base_options = "--debug --no-task ocsdeploy,wakeonlan,snmpquery,netdiscovery";
$base_options .= " --config none" if $regconf;

# first inventory
($out, $err, $rc) = run_executable(
    'fusioninventory-agent',
    "$base_options --local - --no-category printer"
);

subtest "first inventory execution and content" => sub {
    check_execution_ok($err, $rc);
    check_content_ok($out);
};

ok(
    exists $content->{REQUEST}->{CONTENT}->{SOFTWARES},
    'inventory has software'
);

ok(
    exists $content->{REQUEST}->{CONTENT}->{ENVS},
    'inventory has environment variables'
);

# second inventory, without software
($out, $err, $rc) = run_executable(
    'fusioninventory-agent',
    "$base_options --local - --no-category printer,software"
);

subtest "second inventory execution and content" => sub {
    check_execution_ok($err, $rc);
    check_content_ok($out);
};

ok(
    !exists $content->{REQUEST}->{CONTENT}->{SOFTWARES},
    "output doesn't have any software"
);

ok(
    exists $content->{REQUEST}->{CONTENT}->{ENVS},
    'inventory has environment variables'
);

# third inventory, without software, but additional content

my $file = File::Temp->new(UNLINK => $ENV{TEST_DEBUG} ? 0 : 1, SUFFIX => '.xml');
print $file <<EOF;
<?xml version="1.0" encoding="UTF-8" ?>
<REQUEST>
  <CONTENT>
      <SOFTWARES>
          <NAME>foo</NAME>
          <VERSION>bar</VERSION>
      </SOFTWARES>
  </CONTENT>
</REQUEST>
EOF
close($file);

($out, $err, $rc) = run_executable(
    'fusioninventory-agent',
    "$base_options --local - --no-category printer,software --additional-content $file"
);
subtest "third inventory execution and content" => sub {
    check_execution_ok($err, $rc);
    check_content_ok($out);
};

ok(
    exists $content->{REQUEST}->{CONTENT}->{SOFTWARES},
    'inventory has softwares'
);

ok(
    ref $content->{REQUEST}->{CONTENT}->{SOFTWARES} eq 'HASH',
    'inventory contains only one software'
);

ok(
    $content->{REQUEST}->{CONTENT}->{SOFTWARES}->{NAME} eq 'foo' &&
    $content->{REQUEST}->{CONTENT}->{SOFTWARES}->{VERSION} eq 'bar',
    'inventory contains the expected software'
);

ok(
    exists $content->{REQUEST}->{CONTENT}->{ENVS},
    'inventory has environment variables'
);

# PATH through WMI appears with %SystemRoot% templates, preventing direct
# comparaison with %ENV content, OS seems to be a more reliable test then
my $name = $OSNAME eq 'MSWin32' ? 'OS' : 'PATH';
my $value = $ENV{$name};

($out, $err, $rc) = run_executable(
    'fusioninventory-agent',
    "$base_options --local - --no-category printer,software"
);

subtest "fourth inventory execution and content" => sub {
    check_execution_ok($err, $rc);
    check_content_ok($out);
};

ok(
    !exists $content->{REQUEST}->{CONTENT}->{SOFTWARES},
    "inventory doesn't have any software"
);

ok(
    exists $content->{REQUEST}->{CONTENT}->{ENVS},
    'inventory has environment variables'
);

ok(
    (any
        { $_->{KEY} eq $name && $_->{VAL} eq $value }
        @{$content->{REQUEST}->{CONTENT}->{ENVS}}
    ),
    'inventory has expected environment variable value'
);

($out, $err, $rc) = run_executable(
    'fusioninventory-agent',
    "$base_options --local - --no-category printer,software,environment"
);

subtest "fifth inventory execution and content" => sub {
    check_execution_ok($err, $rc);
    check_content_ok($out);
};

ok(
    !exists $content->{REQUEST}->{CONTENT}->{SOFTWARES},
    "inventory doesn't have any software"
);

ok(
    !exists $content->{REQUEST}->{CONTENT}->{ENVS},
    "inventory doesn't have any environment variables"
);

# output location tests
my $dir = File::Temp->newdir(CLEANUP => 1);
($out, $err, $rc) = run_executable(
    'fusioninventory-agent',
    "$base_options --local $dir"
);
subtest "--local <directory> inventory execution" => sub {
    check_execution_ok($err, $rc);
};
ok(<$dir/*.ocs>, '--local <directory> result file presence');

($out, $err, $rc) = run_executable(
    'fusioninventory-agent', "$base_options --local $dir/foo"
);
subtest "--local <file> inventory execution" => sub {
    check_execution_ok($err, $rc);
};
ok(-f "$dir/foo", '--local <file> result file presence');

sub check_execution_ok {
    my ($err, $rc) = @_;

    ok($rc == 0, 'exit status');

    unlike(
        $err,
        qr/module \S+ disabled: failure to load/,
        'no broken module (loading)'
    );

    unlike(
        $err,
        qr/unexpected error in \S+/,
        'no broken module (execution)'
    );
}

sub check_content_ok {
    my ($out) = @_;

    like(
        $out,
        qr/^<\?xml version="1.0" encoding="UTF-8" \?>/,
        'output has correct encoding'
    );

    $content = XML::TreePP->new()->parse($out);
    ok($content, 'output is valid XML');
}
