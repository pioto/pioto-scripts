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
    if ($c++ > 9) {
        $data[10] += $r{$l};
        $labels[10] = "Other ($data[10])";
        next;
    }
    push @data, ($r{$l} / $total * 100);
    push @labels, "$l ($r{$l})";
}
$data[10] = $data[10] / $total * 100;

@data = grep { defined $_ } @data;
@labels = grep { defined $_ } @labels;

my $uri = URI->new('http://chart.apis.google.com/chart');

my $repo_url = $repo->config('remote.origin.url') || $repo->repo_path();
my @branches = $repo->command('branch');
my ($branch) = grep {/^\*/} @branches;
$branch =~ s/^\*\s*// if $branch;
$repo_url .= " on $branch" if $branch && $branch ne 'master';

$uri->query_param('chtt', "Top 10 Authors for $repo_url"); # chart title
$uri->query_param('chs', '650x250'); # chart size
$uri->query_param('cht', 'p3'); # chart type
$uri->query_param('chco', '006600'); # colors
$uri->query_param('chd', 't:'.join(',', @data)); # data
$uri->query_param('chl', join('|', @labels)); # labels

print "$uri\n";

