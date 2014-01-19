#!/usr/bin/perl
use feature ':5.10';
use utf8;
use warnings;
use strict;
use Net::Twitter;
use Scalar::Util 'blessed';

my $conf_file = 'conf/twitter.conf';

my $conf = do $conf_file;

# As of 13-Aug-2010, Twitter requires OAuth for authenticated requests
my $nt = Net::Twitter->new(
    traits              => [qw/OAuth API::RESTv1_1/],
    consumer_key        => $conf->{Consumer_key},
    consumer_secret     => $conf->{Consumer_secret_Access_token},
    access_token        => $conf->{Access_token},
    access_token_secret => $conf->{Access_token_secret},
    ssl => 1
);

my $result = $nt->update('日本語テスト');

