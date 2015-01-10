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
	my $et = HTML::TableExtract->new();
	$et->parse($body);
	$et = $et->first_table_found();

	foreach my $row ($et->rows){
		foreach my $cell (@$row){
			my $a = $cell->find_by_tag_name('a');
			my $title = $a->as_text;
			my $abs_link = URI->new_abs($a->attr('href'),$base_uri)->as_string;
			push @news, {"Title"=>$a->as_text, "URL" => $abs_link, "Description"=> ""};
		}
	}
	return \@news;
}

1;
