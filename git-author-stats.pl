#!/usr/bin/env perl
use strict;
use warnings;

use Git;
use URI;
use URI::QueryParam;

my $repo = Git->repository();

my @shortlog = $repo->command('shortlog', '--summary');

my (%r, $total);
foreach (@shortlog) {
    m/^\s*(\d+)\s+(.+)$/;
    $r{$2}=$1;
    $total += $1;
}

my (@data, @labels, $c);
foreach my $l (sort {$r{$b} <=> $r{$a}} keys %r) {
    if ($c++ > 10) {
        $data[11] += $r{$l};
        $labels[11] = "Other ($data[11])";
        next;
    }
    push @data, ($r{$l} / $total * 100);
    push @labels, "$l ($r{$l})";
}
$data[11] = $data[11] / $total * 100;

@data = grep { defined $_ } @data;
@labels = grep { defined $_ } @labels;

my $uri = URI->new('http://chart.apis.google.com/chart');

$uri->query_param('chs', '650x250'); # chart size
$uri->query_param('cht', 'p3'); # chart type
$uri->query_param('chd', 't:'.join(',', @data)); #
$uri->query_param('chl', join('|', @labels));

print "$uri\n";

