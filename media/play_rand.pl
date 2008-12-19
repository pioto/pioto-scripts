#!/usr/bin/perl -w
#
# Plays a random episode of a show. Defaults to chosing
# from all episodes ending in .avi in the current directory, 
# and to chosing only one episode to play.
#
# Written by Mike Kelly
#
# $Id: play_rand.pl,v 1.8 2005/11/20 18:46:02 mike Exp mike $
our $VERSION = '$Revision: 1.8 $';

use strict;
use Getopt::Std;

# define some defaults
our $PLAYER = 'mplayer';
our $PLAYER_ARGS = '-monitoraspect 16:10 -stop-xscreensaver -vf pp -vo xv -fs';

$Getopt::Std::STANDARD_HELP_VERSION = 1;

my %opt;
getopts("hp:d:n:P:A:vq", \%opt);

sub HELP_MESSAGE {
    print <<EOF;
play_rand.pl takes the following arguments:

    -h		Shows this help message.
    -p pattern	The pattern to match for episodes. A Perl regexp.
    -d dir	The directory to work in.
    -n num	The number of episodes to play.

    -P player	The command to use as the "player". Defaults to: 
		  $PLAYER
    -A args	The arguments to the player. Defaults to:
		  $PLAYER_ARGS

    -v		Turns on verbose output.
    -q		Makes things totally silent.
EOF

    exit;
}

# fisher_yates_shuffle( \@array ) : generate a random permutation
# of @array in place
sub fisher_yates_shuffle (@) {
    my $array = shift;
    for (my $i = @$array; --$i && $i>=0; ) {
        my $j = int rand ($i+1);
        next if $i == $j;
        @$array[$i,$j] = @$array[$j,$i];
    }
}

# handle our arguments, and load default values.

HELP_MESSAGE if($opt{"h"});

my $pattern = '*avi';
my $dir = `pwd`;
my $num = 1;

my $player = $PLAYER;
my $player_args = $PLAYER_ARGS;

if(defined $opt{"p"}) { $pattern = $opt{"p"}; }
if(defined $opt{"d"}) { $dir = $opt{"d"}; }
if(defined $opt{"n"}) { $num = $opt{"n"}; }

if(defined $opt{"P"}) { $player = $opt{"P"}; }
if(defined $opt{"A"}) { $player_args = $opt{"A"}; }

# trim the newline off of $dir, if necessary
$dir =~ s/^\s*(.*)\s*$/$1/;

# now, build our list of matching files
#my $rawFiles = `ls "$dir"`;
if($opt{"v"}) {
    print "DBG: find \"$dir\" -iname \"$pattern\" -print\n";
}

my $rawFiles = `find "$dir" -iname "$pattern" -type f -print`;

my @files = ( );

@files = split '\n', $rawFiles;

foreach (@files) {
    if($opt{"v"}) {
	print "DBG: $_\n";
    }
}

# now, randomize the array
fisher_yates_shuffle(\@files);

# now, truncate the list to be the first $num entries
my @finalFiles = ( );

for (my $i=0; ($i<$num) && ($i <= $#files); $i++) {
    push @finalFiles, $files[$i];
}

if(! defined $opt{"q"}) {
    print "Now playing the following:\n";
    foreach (@finalFiles) {
	print "  $_\n";
    }
}

# finally, play these things
foreach (@finalFiles) {
    $player_args = "$player_args \"$_\"";
}

if($opt{"v"}) {
    print "\n";
    exec "$player $player_args";
} else {
    exec "$player $player_args >/dev/null 2>&1";
}
