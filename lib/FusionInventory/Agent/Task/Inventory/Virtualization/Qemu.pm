package FusionInventory::Agent::Task::Inventory::Virtualization::Qemu;
# With Qemu 0.10.X, some option will be added to get more and easly information (UUID, memory, ...)

use strict;
use warnings;

use FusionInventory::Agent::Tools;
use FusionInventory::Agent::Tools::Unix;

sub isEnabled {
    # Avoid duplicated entry with libvirt
    return if canRun('virsh');

    return
        canRun('qemu') ||
        canRun('kvm')  ||
        canRun('qemu-kvm');
}

sub _parseProcessList {
    my ($process) = @_;


    my $values = {};

    my @options = split (/ -/, $process->{CMD});

    foreach my $option (@options) {
        if ($option =~ m/^(?:[fhsv]d[a-d]|cdrom) (\S+)/) {
            $values->{name} = $1 if !$values->{name};
        } elsif ($option =~ m/^name (\S+)/) {
            $values->{name} = $1;
        } elsif ($option =~ m/^m (\S+)/) {
            $values->{mem} = $1;
        } elsif ($option =~ m/^uuid (\S+)/) {
            $values->{uuid} = $1;
        }

        if ($option =~ /smbios/) {
            if ($option =~ m/smbios.*uuid=([a-zA-Z0-9-]+)/) {
                $values->{uuid} = $1;
            }
            if ($option =~ m/smbios.*serial=([a-zA-Z0-9-]+)/) {
                $values->{serial} = $1;
            }
        }
    }

    if ($values->{mem} == 0 ) {
        # Default value
        $values->{mem} = 128;
    }

    return $values;
}

sub doInventory {
    my (%params) = @_;

    my $inventory = $params{inventory};
    my $logger    = $params{logger};

    foreach my $process (getProcesses(logger => $logger)) {
        # match only if an qemu instance
        next if $process->{CMD} =~ /^\[/;
        next if $process->{CMD} !~ /(qemu|kvm|qemu-kvm|qemu-system\S+) .*\S/x;

        my $values = _parseProcessList($process);
        next unless $values;

        $inventory->addEntry(
            section => 'VIRTUALMACHINES',
            entry => {
                NAME      => $values->{name},
                UUID      => $values->{uuid},
                VCPU      => 1,
                MEMORY    => $values->{mem},
                STATUS    => "running",
                SUBSYSTEM => $values->{vmtype},
                VMTYPE    => $values->{vmtype},
                SERIAL    => $values->{serial},
            }
        );
    }
}

1;
