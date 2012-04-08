#!/usr/bin/env perl
use warnings;
use strict;

use DateTime::Format::Strptime;
use List::Util qw(max);
use POSIX qw(:sys_wait_h); # for WEXITSTATUS
use YAML;

use constant ZFS => '/sbin/zfs';

my %DEFAULTS = (
    yearly => undef, # keep all 'yearly'
    monthly => undef, # keep all 'monthly'
    weekly => 4, # keep the last 4 weeks
    daily => 6, # keep the last 6 day's
    hourly => 24, # keep the last 24 hours
);

my $SNAPSHOT_TYPE_PROP = 'org.pioto:snapshot_type';

my $DEBUG = 0;
my $verbose = -t;

my %zfs;
my $root_ds = shift;
my @zfs_get_cmd = (ZFS, 'get', '-Hp');
if ($root_ds) {
    push @zfs_get_cmd, '-r';
}
push @zfs_get_cmd, 'all';
if ($root_ds) {
    push @zfs_get_cmd, $root_ds;
}
open my $props, '-|', @zfs_get_cmd
    or die "Failed to fork `zfs`: $!";
while (defined(my $line = <$props>)) {
    my %n;
    chomp $line;
    @n{qw(name property value source)} = split /\t/, $line;
    $zfs{$n{name}}{$n{property}} = $n{value};
    if ($DEBUG && $n{property} eq 'creation') {
        $zfs{$n{name}}{creation_human} = ''.localtime($n{value});
    }
}
unless (close $props) {
    if ($? == -1) {
        die "Failed to fork `zfs get`: $!";
    }
    die "Failed to get zfs properties: ".WEXITSTATUS($?);
}

my $dt_fmt = DateTime::Format::Strptime->new(
    pattern => '%FT%T',
    time_zone => 'local',
);

my %datasets;
while (my ($name, $props) = each %zfs) {
    if ($props->{type} =~ /^(?:filesystem|volume)$/) {
        $datasets{$name} = {%{$datasets{$name}||{}}, %$props};
    } elsif ($props->{type} eq 'snapshot') {
        my ($ds_name, $snapshot_name) = split /[@]/, $name, 2;
        my $snapdate = $snapshot_name;
        $snapdate =~ s/-\wly$//;
        $props->{snapshot_date} = $dt_fmt->parse_datetime($snapdate);
        $datasets{$ds_name}{snapshots}{$snapshot_name} = $props;
    } else {
        warn "Unknown dataset type '$props->{type}' for $name";
    }
}

#print Dump(\%datasets) if $DEBUG;

my %snapshots_by_type;
while (my ($ds_name, $ds_props) = each %datasets) {
    my %seen;
    my $snapshots = $ds_props->{snapshots};
    foreach my $ss_name (sort {$snapshots->{$a}{snapshot_date} <=> $snapshots->{$b}{snapshot_date}} grep {$snapshots->{$_}{snapshot_date}} keys %$snapshots) {
        my $ss_props = $ds_props->{snapshots}{$ss_name};
        my $ss_date = $ss_props->{snapshot_date};
        my $ss_type;
        if ($seen{year}{$ss_date->year}) {
            if ($seen{month}{$ss_date->year}{$ss_date->month}) {
                if ($seen{week}{$ss_date->week_year}{$ss_date->week_number}) {
                    if ($seen{day}{$ss_date->ymd}) {
                        $ss_type = 'hourly';
                    } else {
                        $ss_type = 'daily';
                    }
                } else {
                    $ss_type = 'weekly';
                }
            } else {
                $ss_type = 'monthly';
            }
        } else {
            $ss_type = 'yearly';
        }
        $seen{year}{$ss_date->year}++;
        $seen{month}{$ss_date->year}{$ss_date->month}++;
        $seen{week}{$ss_date->week_year}{$ss_date->week_number}++;
        $seen{day}{$ss_date->ymd}++;

        push @{$snapshots_by_type{$ds_name}{$ss_type}}, $ss_name;
        if (!$ss_props->{$SNAPSHOT_TYPE_PROP} || $ss_props->{$SNAPSHOT_TYPE_PROP} ne $ss_type) {
            if (my $t = $ss_props->{$SNAPSHOT_TYPE_PROP}) {
                warn "Changing snapshot type from $t to $ss_type for $ds_name\@$ss_name";
            }
            my @cmd = (ZFS, 'set', "$SNAPSHOT_TYPE_PROP=$ss_type", $ds_name.'@'.$ss_name);
            print "# @cmd\n" if $verbose;
            unless ($DEBUG) {
                system(@cmd)
                    and die "@cmd failed: $? $!";
            }
        }
    }
    @{$snapshots_by_type{$ds_name}{UNKNOWN}} = grep {!$snapshots->{$_}{snapshot_date}} keys %$snapshots;
}

print Dump(\%snapshots_by_type) if $DEBUG;

while (my ($ds_name, $ss_types) = each %snapshots_by_type) {
    while (my ($ss_type, $ss_names) = each %$ss_types) {
        my $type_limit = $DEFAULTS{$ss_type};
        if (defined $type_limit) {
            while (0+@$ss_names > $type_limit) {
                my $name = shift @$ss_names;
                my @cmd = (ZFS, "destroy", "$ds_name\@$name");
                print "# @cmd\n" if $verbose;
                unless ($DEBUG) {
                    system(@cmd)
                        and die "@cmd failed: $? $!";
                }
            }
        }
    }
}

exit;


