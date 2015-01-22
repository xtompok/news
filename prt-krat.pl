#!/usr/bin/perl
#
use common::sense;
use WWW::Mechanize;
use HTML::TreeBuilder;
use HTML::TableExtract qw(tree);
use URI;

use Data::Dumper;

sub get_news($){
	my $url = $_[0];

	my @news = ();

	my $m = WWW::Mechanize->new();
	my $page = $m->get($url);
	my $base_uri = $m->uri();
	dprint $m->ct."\n";
	my $body = $page->decoded_content;
	my $tree = HTML::TreeBuilder->new();
	$tree->parse_content($body);
	my @kratasy = $tree->look_down("class"=>"tabulkakratas");
	foreach my $item (@kratasy){
		my $url = $base_uri.$item->look_down(class=>"text1odkaz")->attr('href');
		my $desc = $item->look_down(class=>'text1kratas')->as_text();
		$desc =~ s/ +/ /g;
		my $title = $item->look_down(class=>'text1nadpis')->as_text().":";
		$title .= substr($desc,0,80-length($title))."...";
		push @news, { Title=>$title, URL=>$url, Description=>$desc};
	}
	return \@news;
}

1;
