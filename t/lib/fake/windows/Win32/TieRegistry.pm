package Win32::TieRegistry;

use strict;
use warnings;

use constant REG_SZ    => 0x1;
use constant REG_DWORD => 0x4;

our $Registry;

sub import {
    my $callpkg = caller();
    no strict 'refs';

    *{"$callpkg\::Registry"} = \$Registry;
    *{"$callpkg\::KEY_READ"} = sub {};
    *{"$callpkg\::REG_SZ"}    = sub { REG_SZ };
    *{"$callpkg\::REG_DWORD"} = sub { REG_DWORD };
}

sub GetValue {
    my ($self, $value ) = @_ ;
    # Subkey case
    if ($value && exists($self->{$value})) {
        return wantarray ? () : undef ;
    }
    # Value case
    $value = '/'.$value;
    return unless ($value && exists($self->{$value}));
    return wantarray ?
        ( $self->{$value}, $self->{$value} =~ /^0x/ ? REG_DWORD : REG_SZ )
        : $self->{$value} ;
}

1;
