package FusionInventory::Agent::Task::Inventory::MacOS::CPU;

use strict;
use warnings;

use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Tools::MacOS;

sub isEnabled {
    my (%params) = @_;
    return 0 if $params{no_category}->{cpu};
    return canRun('/usr/sbin/system_profiler');
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};
    my $logger    = $params{logger};

    foreach my $cpu (_getCpus(logger => $logger)) {
        $inventory->addEntry(
            section => 'CPUS',
            entry   => $cpu
        );
    }
}

sub _getCpus {
    my (%params) = @_;

    # system profiler informations
    my $infos = getSystemProfilerInfos(
        type   => 'SPHardwareDataType',
        logger => $params{logger},
        file   => $params{file}
    );

    my $sysprofile_info = $infos->{'Hardware'}->{'Hardware Overview'};

    # more informations from sysctl
    my $handle = getFileHandle(
        logger  => $params{logger},
        command => 'sysctl -a machdep.cpu',
        file    => $params{sysctl}
    );

    my $sysctl_info;
    while (my $line = <$handle>) {
        chomp $line;
        next unless $line =~ /([^:]+) : \s (.+)/x;
        $sysctl_info->{$1} = $2;
    }
    close $handle;

    my $type  = $sysctl_info->{'machdep.cpu.brand_string'} || 
                $sysprofile_info->{'Processor Name'} ||
                $sysprofile_info->{'CPU Type'};
    my $procs = $sysprofile_info->{'Number Of Processors'} ||
                $sysprofile_info->{'Number Of CPUs'}       ||
                1;
    my $speed = $sysprofile_info->{'Processor Speed'} ||
                $sysprofile_info->{'CPU Speed'};

    my $stepping = $sysctl_info->{'machdep.cpu.stepping'};
    my $family   = $sysctl_info->{'machdep.cpu.family'};
    my $model    = $sysctl_info->{'machdep.cpu.model'};
    my $threads  = $sysctl_info->{'machdep.cpu.thread_count'};

    # French Mac returns 2,60 Ghz instead of 2.60 Ghz :D
    $speed =~ s/,/./;
    if ($speed =~ /GHz$/i) {
        $speed =~ s/GHz//i;
        $speed = $speed * 1000;
    } elsif ($speed =~ /MHz$/i){
        $speed =~ s/MHz//i;
    }
    $speed =~ s/\s//g;

    my $cores = $sysprofile_info->{'Total Number Of Cores'} ?
        $sysprofile_info->{'Total Number Of Cores'} / $procs :
        $sysctl_info->{'machdep.cpu.core_count'};

    my $manufacturer =
        $type =~ /Intel/i ? "Intel" :
        $type =~ /AMD/i   ? "AMD"   :
                            undef   ;

    my @cpus;
    my $cpu = {
        CORE         => $cores,
        MANUFACTURER => $manufacturer,
        NAME         => trimWhitespace($type),
        THREAD       => $threads,
        FAMILYNUMBER => $family,
        MODEL        => $model,
        STEPPING     => $stepping,
        SPEED        => $speed
    };

    for (my $i=0; $i < $procs; $i++) {
        push @cpus, $cpu;
    }

    return @cpus;

}



1;
