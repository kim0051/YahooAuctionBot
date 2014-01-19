#!/usr/bin/perl
use strict;
use warnings;
use feature ':5.10';
use Net::Twitter;
use Data::Dumper;
use Encode;
use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);
use HTTP::Request::Common qw(POST);
use HTTP::Date;
use JSON;
use LWP::UserAgent;
use Pod::Usage;
use utf8;
use URI::Escape;

my ($conf_file);

GetOptions(
    "twitter=s" => \my $twitter_conf,
    "yahoo=s" => \my $yahoo_conf,
);
#exit;
#TODO Twitterサーバーが５０３の時、おそらくプロセス死ぬが外側からSYSTEM呼び出しするので大丈夫
#Yahoo! Auction  API呼び出し制限＝5万/Day (http://developer.yahoo.co.jp/webapi/auctions/)

#my $twitter_conf = 'conf/twitter_conf.pl';
#my $yahoo_conf = 'conf/yahoo_conf.pl';

my $conf;
$conf->{YahooJapan} = do $yahoo_conf;
$conf->{Twitter} = do $twitter_conf;

print Dumper $conf->{YahooJapan};
#exit;

my $yahoo_url = 'http://auctions.yahooapis.jp/AuctionWebService/V2/json/search';
my $affiliate_id = $conf->{YahooJapan}->{affiliate_id};
my $affiliate_url =
'http://atq.ck.valuecommerce.com/servlet/atq/referral?sid=2219441&pid=877510753&vcptn='
  . $affiliate_id
  . '&vc_url=';

my $application_key = $conf->{YahooJapan}->{application_key};
my $OS_WINDOWS = 'MSWin32';

my $max = 20;
#1回のツイートで間隔をあける秒数
my $tweet_sleep_time = 10;

my %options;
$options{'query'} = "コミケ c85";
$options{'sort'}  = "bids";
$options{"order"} = "a";
$options{"page"}  = 1;
$options{"hashtag"} = "#C85";

get_data( \%options );

sub get_data {
	my $options = shift;

	my $ua      = LWP::UserAgent->new;

	my $req = POST $yahoo_url,
	  [
		appid => $application_key,
		query => $options->{query},
		sort  => $options->{sort},
		order => $options->{order},
		page  => $options->{page}
	  ];

	my $result_jsonp = $ua->request($req)->content;

	#JSONP形式なのでJSON形式にする
	$result_jsonp =~ s/^loaded\((.*)\)$/$1/;

	my $result = decode_json $result_jsonp;

	my $att = $result->{'ResultSet'}->{'@attributes'};

	for my $var ( keys %$att ) {
		say $var. " = " . $att->{$var};
	}

	#アイテムリスト出力
	my $item_ref = $result->{ResultSet}->{Result}->{Item};

    #ツイート文
    my @tweets;

	if ( $result->{'ResultSet'}->{'@attributes'}->{totalResultsReturned} == 1 )
	{
		my $line = item_output($item_ref);
		push(@tweets,$line);
	}
	else {
		my $counter = 0;
		foreach my $var (@$item_ref) {
			$counter++;
			my $line = item_output($var , $options->{hashtag});
			#say $line;
            push(@tweets,$line);
			last if $max == $counter;

		}

	}

	tweet(@tweets);
}

sub item_output {
	my $var = shift;
	my $hash_tag = shift;

	#入札数
	my $bids = $var->{Bids} || 0;

	my $title = utf_conversion( $var->{Title} );

	my $encded_auc_url = uri_escape( $var->{AuctionItemUrl} );
	my $affi_url       = $affiliate_url . $encded_auc_url;


    my $sokketu;
	if ( $var->{BidOrBuy} ) {
		$sokketu=sprintf( "即決価格=%d円 ", $var->{BidOrBuy} );
	}
	else {
	   $sokketu="即決価格=なし ";
	}

	#終了時間 RFC3339形式なので変換する
	my $t      = HTTP::Date::str2time( $var->{EndTime} );
	my $endate = HTTP::Date::time2iso($t);

    $endate = "終了時間=".$endate;

    my $cprice = sprintf( " 現在価格=%d円 ", $var->{CurrentPrice} );

    #my $image = "";
    #twipicとかじゃないとサムネイル表示されないので意味が無い
    #$image ||= $var->{Image};

	my $return_st = $title." 入札数=".$bids.$cprice.$sokketu.$endate. " " .  $affi_url . " " . $hash_tag;

	return $return_st;
}

sub utf_conversion {
	my $var = shift;
	encode( 'UTF-8', $var );
	#Encode::_utf8_off($var);
	#Encode::from_to( $var, 'utf-8', 'shiftjis' ) if $^O eq $OS_WINDOWS;
	return $var;
}

#引数にツイート文の配列を格納
sub tweet {
	my @lines = @_;
	use Net::Twitter;
	use Scalar::Util 'blessed';

	my $nt = Net::Twitter->new(
		traits              => [qw/OAuth API::RESTv1_1/],
		consumer_key        => $conf->{Twitter}->{Consumer_key},
		consumer_secret     => $conf->{Twitter}->{Consumer_secret_Access_token},
		access_token        => $conf->{Twitter}->{Access_token},
		access_token_secret => $conf->{Twitter}->{Access_token_secret},
		ssl => 1, # 2014/01/15 https://dev.twitter.com/discussions/24239
	);

	for my $tweet_line (@lines) {
		eval {
			say "tweet!";
        		$nt->update($tweet_line);
		};
		if($@) {
			say "error";
			say $@;
		}
		sleep($tweet_sleep_time);
	}

}

