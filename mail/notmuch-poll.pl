#!/usr/bin/env perl

use warnings;
use strict;

use JSON;
use MIME::Parser;
use IO::CaptureOutput qw(qxx);

my $MAILDIR = '/home/pioto/.maildir';
my $NEW_QUERY = 'tag:new';

my %HEADER_TAGS = (
    'X-Spam-Flag' => [ {regex => qr/^YES$/, tags => ['+spam']} ],
    'X-Bogosity' => [ {regex => qr/^Spam,/, tags => ['+spam', '+bogofilter']} ],
    'List-Id' => [
        {regex => qr//, tags => ['+list']},
        {regex => qr/exherbo-commits\.lists\.exherbo\.org/, tags => ['+exherbo-commits']},
        {regex => qr/exherbo-dev\.lists\.exherbo\.org/, tags => ['+exherbo-dev']},
        {regex => qr/paludis-(?:user|sekrit|dev|commits)\.lists\.pioto\.org/, tags => ['+paludis']},
    ],
    'Subject' => [
        {regex => qr/Log[wW]atch/, tags => ['+logwatch']},
    ],
    'From' => [
        {regex => qr/root@.*pioto\.org/, tags => ['+system']},
    ],
);
my %FOLDER_TAGS = (
    'INBOX' => ['+inbox'],
);
my %MAILDIR_FLAG_TAGS = (
    '!DEFAULT' => ['+unread'],
    'P' => ['+forwarded'], # passed
    'R' => ['+replied'], # replied
    'S' => ['-unread'], # seen
    'T' => ['+trash'], # trashed
    'D' => ['+draft'], # draft
    'F' => ['+flagged'], # flagged
);

main(@ARGV);

exit 0;

sub main {
    # check for new messages. they'll be tagged to match the $NEW_QUERY
    system 'notmuch', 'new';

    chomp(my $new_count = qxx('notmuch', 'count', $NEW_QUERY));
    print "Parsing $new_count new messages...\n";
    exit 0 unless $new_count; # notmuch search gives invalid JSON if there are no results...
    my $new_messages = decode_json(qxx('notmuch', 'search', '--format=json', '--output=messages', $NEW_QUERY));

    foreach my $message_id (@$new_messages) {
        my $message = decode_json(qxx('notmuch', 'show', '--format=json', "id:$message_id"))->[0][0][0];
        my $raw_message = qxx('notmuch', 'show', '--format=raw', "id:$message_id");

        handle_message($message_id, $message, $raw_message);
    }
}

sub handle_message {
    my ($message_id, $message, $raw_message) = @_;

    tag_by_headers($message_id, $message, $raw_message);

    tag_by_folder($message_id, $message);

    tag_by_maildir_flag($message_id, $message);

    message_tag($message_id, '-new');
}

sub tag_by_headers {
    my ($message_id, $message, $raw_message) = @_;

    my $parser = MIME::Parser->new();
    $parser->output_to_core(1);
    my $entity = $parser->parse_data($raw_message);
    my $head = $entity->head();
    $head->unfold();

    while (my ($h, $t) = each %HEADER_TAGS) {
        my $hv = $head->get($h);
        if ($hv) {
            foreach my $ht (@$t) {
                if ($hv =~ $ht->{regex}) {
                    message_tag($message_id, @{$ht->{tags}});
                }
            }
        }
    }
}

sub tag_by_folder {
    my ($message_id, $message) = @_;

    my ($folder) = $message->{filename} =~ m#^$MAILDIR(?:/([^/]+))?/(?:cur|new)/[^/]+$#;
    $folder = '' unless defined $folder;
    $folder = "INBOX$folder";
    my $folder_tags = $FOLDER_TAGS{$folder};
    if ($folder_tags) {
        message_tag($message_id, @$folder_tags);
    }
}

sub tag_by_maildir_flag {
    my ($message_id, $message) = @_;

    my ($md_tags) = $message->{filename} =~ /:2,([a-zA-Z]+)/
        or return;
    my @md_tags = split //, $md_tags;
    if (my $def_maildir_tags = $MAILDIR_FLAG_TAGS{'!DEFAULT'}) {
        message_tag($message_id, @$def_maildir_tags);
    }
    foreach my $md_tag (@md_tags) {
        if (my $maildir_tags = $MAILDIR_FLAG_TAGS{$md_tag}) {
            message_tag($message_id, @$maildir_tags);
        }
    }
}

sub message_tag {
    my ($message_id, @tags) = @_;

    system 'notmuch', 'tag', @tags, '--', "id:$message_id";
}

