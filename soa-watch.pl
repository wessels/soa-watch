#!/usr/bin/perl

use strict;
use warnings;
use Net::DNS;
use Curses;
use POSIX qw(strftime);
use Getopt::Long;

my @SERVERS;
my @ZONES;
my $SCW = 15;	# Serial Column Width
my $SLEEP = 3;

usage() unless GetOptions (
	"server=s" => \@SERVERS,
	"zone=s" => \@ZONES,
	"sleep=i" => \$SLEEP,
);

my $MAXZONELEN = 0;
foreach my $z (@ZONES) { $MAXZONELEN = length($z) if length($z) > $MAXZONELEN; }
my $MAXSRVRLEN = 0;
foreach my $s (@SERVERS) { $MAXSRVRLEN = length($s) if length($s) > $MAXSRVRLEN; }

initscr;
my $win = new Curses;
while (1) {
	if (scalar(@ZONES) > scalar(@SERVERS)) {
		display1();
	} else {
		display2();
	}
	sleep($SLEEP);
}
endwin;
exit;

sub display1 {
	my $Y = 0;
	my $SN;

	$win->move($Y, 0);
	$win->addstr("Zone");
	$SN = 0; foreach my $s (@SERVERS) {
		$win->move($Y, $MAXZONELEN+($SN*$SCW));
		$win->addstr(sprintf "%${SCW}s", $s);
		$SN++;
	}

	$win->move(++$Y, 0);
	$win->addstr('-'x$MAXZONELEN);
	$SN = 0; foreach my $s (@SERVERS) {
		$win->move($Y, $MAXZONELEN+($SN*$SCW));
		$win->addstr('  '. '-'x($SCW-2));
		$SN++;
	}
	foreach my $z (@ZONES) {
		++$Y;
		$win->move($Y, 0);
		$win->addstr($z);
		$SN = 0; foreach my $s (@SERVERS) {
			$win->move($Y, $MAXZONELEN+($SN*$SCW));
			$win->addstr(sprintf "%${SCW}s", serial($s,$z));
			$SN++;
			$win->move($win->getmaxy-1, 0);
			$win->addstr(strftime('%Y-%m-%d %T UTC', gmtime(time)));
			$win->refresh;
		}
	}
}

sub display2 {
	my $Y = 0;
	my $SN;

	$win->move($Y, 0);
	$win->addstr("Server");
	$SN = 0; foreach my $z (@ZONES) {
		$win->move($Y, $MAXSRVRLEN+($SN*$SCW));
		$win->addstr(sprintf "%${SCW}s", $z);
		$SN++;
	}

	$win->move(++$Y, 0);
	$win->addstr('-'x$MAXSRVRLEN);
	$SN = 0; foreach my $z (@ZONES) {
		$win->move($Y, $MAXSRVRLEN+($SN*$SCW));
		$win->addstr('  '. '-'x($SCW-2));
		$SN++;
	}
	foreach my $s (@SERVERS) {
		++$Y;
		$win->move($Y, 0);
		$win->addstr($s);
		$SN = 0;
		foreach my $z (@ZONES) {
			$win->move($Y, $MAXSRVRLEN+($SN*$SCW));
			$win->addstr(sprintf "%${SCW}s", serial($s,$z));
			$SN++;
			$win->move($win->getmaxy-1, 0);
			$win->addstr(strftime('%Y-%m-%d %T UTC', gmtime(time)));
			$win->refresh;
		}
	}
}

sub serial {
	my $nsaddr = shift;
	my $zone = shift;
	my $res = Net::DNS::Resolver->new;
	$res->nameserver($nsaddr);
	$res->udp_timeout(1);
	$res->recurse(0);
	$res->retry(1);
	my $pkt = $res->send($zone, 'SOA');
	return 'T' unless $pkt;
	return 'R' if $pkt->header->rcode eq 'REFUSED';
	return 'S' if $pkt->header->rcode eq 'SERVFAIL';
	foreach my $rr ($pkt->answer) {
		next unless $rr->type eq 'SOA';
		#return strftime ('%H:%M:%S', gmtime($rr->serial));
		return $rr->serial;
	}
	return '-';
}

sub usage {
	printf STDERR "usage: $0 [--server server] [--zone zone] [--sleep secs]\n";
	exit(1);
}
