#!/usr/bin/perl
while (1) {
	system("perl -I./local/lib/perl5 core.pl --twitter conf/twitter_conf.pl --yahoo conf/yahoo_conf.pl");
	sleep(60*30);#30 min
}
