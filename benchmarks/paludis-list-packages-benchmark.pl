#!/usr/bin/env perl
use warnings;
use strict;

use Benchmark qw(:all :hireswallclock);

my $old_bin = '/usr/bin';
my $new_bin = '/home/pioto/paludis/bin';

timethese(20, {
    'Paludis_Old_Cold' => sub {
        drop_cache();
        system "$old_bin/paludis --list-packages >/dev/null"; },
    'Paludis_Old_Hot' => sub {
        system "$old_bin/paludis --list-packages >/dev/null"; },
    'Paludis_New_Cold' => sub {
        drop_cache();
        system "$new_bin/paludis --list-packages >/dev/null"; },
    'Paludis_New_Hot' => sub {
        system "$new_bin/paludis --list-packages >/dev/null"; },
    'Cave_Old_Cold' => sub {
        drop_cache();
        system "$old_bin/cave print-packages >/dev/null"; },
    'Cave_Old_Hot' => sub {
        system "$old_bin/cave print-packages >/dev/null"; },
    'Cave_New_Cold' => sub {
        drop_cache();
        system "$new_bin/cave print-packages >/dev/null"; },
    'Cave_New_Hot' => sub {
        system "$new_bin/cave print-packages >/dev/null"; },
});

exit 0;

sub drop_cache {
    system 'echo 2 > /proc/sys/vm/drop_caches';
}

