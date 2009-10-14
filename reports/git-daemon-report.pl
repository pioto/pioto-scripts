#!/usr/bin/env perl

use warnings;
use strict;

use Socket;
use Sys::Hostname;

my $HOSTNAME = hostname();

my $results = scan_logs();
report($results);

exit;

sub scan_logs {
    my %results;
    while (<>) {
        #my $pos = tell;
        my ($date, $time, $pid, $ip) =
        m/^(\w+\s+\d+)\s+(\d+:\d+:\d+)\s+$HOSTNAME\s+git-daemon\[(\d+)\]: Connection from ((?:\d+\.){3}\d+):\d+$/
            or next;
        my ($request, $repo);
        while (<>) {
            last if (($request, $repo) = $_ =~ m/git-daemon\[$pid\]: Request (.+) for '\/?(.+?)(?:\.git)?\/?'$/);
        }
        my ($disconnected);
        while (<>) {
            if (m/git-daemon\[\d+\]: \[$pid\] Disconnected$/) {
                $disconnected++;
                last;
            }
        }

        $results{$repo}{$ip}++;

        #print "T=$date $time; REPO=$repo; REQ=$request; DIS=$disconnected\n";
        #seek ARGV, $pos, 0;
    }
    return \%results;
}

sub report {
    my ($results) = @_;
    foreach my $repo (sort keys %$results) {
        my $ips = $results->{$repo};
        printf "%s:\n", $repo;
        foreach my $ip (sort {$ips->{$b} <=> $ips->{$a}} keys %$ips) {
            my $host = _resolve_ip($ip);
            printf "%4d: %s\n", $ips->{$ip}, $host;
        }
    }
}

sub _resolve_ip {
    my ($ip) = @_;

    my $iaddr = inet_aton($ip);
    my $host;
    if ($iaddr) {
        $host = gethostbyaddr($iaddr, AF_INET);
        $host .= " [$ip]" if defined $host;
    }

    return defined $host ? $host : $ip;
}

