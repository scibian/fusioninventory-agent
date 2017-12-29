package FusionInventory::Agent::Task::Inventory::BSD::Uptime;

use strict;
use warnings;

use FusionInventory::Agent::Tools;

sub isEnabled {
    return canRun('sysctl');
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};

    my $arch = getFirstLine(command => 'uname -m');
    my $uptime = _getUptime(command => 'sysctl -n kern.boottime');
    $inventory->setHardware({
        DESCRIPTION => "$arch/$uptime"
    });
}

sub _getUptime {
    my $line = getFirstLine(@_);

    # the output of 'sysctl -n kern.boottime' differs between BSD flavours
    my $boottime =
        $line =~ /^(\d+)/      ? $1 : # OpenBSD format
        $line =~ /sec = (\d+)/ ? $1 : # FreeBSD format
        undef;
    return unless $boottime;

    my $uptime = $boottime - time();
    return getFormatedGMTTime($uptime);
}

1;
