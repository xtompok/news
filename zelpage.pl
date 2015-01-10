#!/usr/bin/perl
#
use common::sense;
use WWW::Mechanize;
use HTML::TreeBuilder;
use HTML::TableExtract qw(tree);
use URI;

use Data::Dumper;

sub get_news($){

	my $m = WWW::Mechanize->new();

	my $page = $m->get('http://www.prazsketramvaje.cz/uvod.htmxl');
	my $base_uri = $m->uri();
	my $body = $page->decoded_content;
	my $t = HTML::TreeBuilder->new_from_content($body);
	my $title = $t->find_by_tag_name('title');
	my $table = $t->find_by_tag_name('TABLE');


	my $et = HTML::TableExtract->new();
	$et->parse($body);
	$et = $et->first_table_found();

	foreach my $row ($et->rows){
		foreach my $cell (@$row){
			my $a = $cell->find_by_tag_name('a');
			print "> ";
			print $a->as_text;
			print " |	";
			my $abs_link = URI->new_abs($a->attr('href'),$base_uri);
			print $abs_link->as_string;
		}
		print "\n";
	}
	print $title->as_text;

}

1;
