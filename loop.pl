#!/usr/bin/perl
while (1) {
	system("perl -I./local/lib/perl5 core.pl --twitter conf/twitter.conf --yahoo conf/yahoo.conf");
	sleep(60*30);#30 min
}
