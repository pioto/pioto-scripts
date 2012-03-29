#!/usr/bin/env perl
use warnings;
use strict;

use List::Util qw(max);
use POSIX qw(:sys_wait_h); # for WEXITSTATUS
use YAML;

use constant ZFS => '/sbin/zfs';

my %DEFAULTS = (
    monthly => undef, # keep all 'monthly'
    weekly => 4, # keep the last 4 weeks
    daily => 6, # keep the last 6 day's
    hourly => 24, # keep the last 24 hours
);

my $verbose = -t;

my %zfs;
open my $props, '-|', ZFS, 'get', '-Hp', 'all'
    or die "Failed to fork `zfs`: $!";
while (defined(my $line = <$props>)) {
    my %n;
    chomp $line;
    @n{qw(name property value source)} = split /\t/, $line;
    $zfs{$n{name}}{$n{property}} = $n{value};
    if ($n{property} eq 'creation') {
        $zfs{$n{name}}{creation_human} = ''.localtime($n{value});
    }
}
unless (close $props) {
    if ($? == -1) {
        die "Failed to fork `zfs get`: $!";
    }
    die "Failed to get zfs properties: ".WEXITSTATUS($?);
}

my %datasets;
while (my ($name, $props) = each %zfs) {
    if ($props->{type} =~ /^(?:filesystem|volume)$/) {
        $datasets{$name} = {%{$datasets{$name}||{}}, %$props};
    } elsif ($props->{type} eq 'snapshot') {
        my ($ds_name, $snapshot_name) = split /[@]/, $name, 2;
        $props->{snapshot_type} = snapshot_type($snapshot_name, $props);
        $datasets{$ds_name}{snapshots}{$snapshot_name} = $props;
    } else {
        warn "Unknown dataset type '$props->{type}' for $name";
    }
}

#print Dump(\%datasets);

my %snapshots_by_type;
while (my ($ds_name, $ds_props) = each %datasets) {
    while (my ($ss_name, $ss_props) = each %{$ds_props->{snapshots}}) {
        my $t = $ss_props->{snapshot_type} || 'UNKNOWN';
        push @{$snapshots_by_type{$ds_name}{$t}}, $ss_name;
    }
    while (my ($ss_type, $ss_names) = each %{$snapshots_by_type{$ds_name}}) {
        $snapshots_by_type{$ds_name}{$ss_type} = [sort @$ss_names];
    }
}

#print Dump(\%snapshots_by_type);

while (my ($ds_name, $ss_types) = each %snapshots_by_type) {
    while (my ($ss_type, $ss_names) = each %$ss_types) {
        my $type_limit = $DEFAULTS{$ss_type};
        if (defined $type_limit) {
            while (0+@$ss_names > $type_limit) {
                my $name = shift @$ss_names;
                my @cmd = (ZFS, "destroy", "$ds_name\@$name");
                print "# @cmd\n" if $verbose;
                system(@cmd)
                    and die "@cmd failed: $? $!";
            }
        }
    }
}

exit;

sub snapshot_type {
    my ($snapshot_name, $props) = @_;

    # ready for the year 10000 :p
    my ($type) = $snapshot_name =~
    /^\d{4,}-\d\d-\d\dT\d\d:\d\d:\d\d-((?:month|week|dai|hour)ly)$/;
    return $type;
}

