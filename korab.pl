#!/usr/bin/perl

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
	my $body = $page->decoded_content;
	my $t = HTML::TreeBuilder->new_from_content($body);
	my $htmlbody = $t->find_by_tag_name('body');
	my @elems = $htmlbody->descendants();
	my $i = 0;
	do {$i++} while ($elems[$i]->tag ne 'h4');
	my $title = $elems[$i]->as_text;
	$i++;
	my $text = "";
	while ($i < @elems){
		if ($elems[$i]->tag eq 'h4'){
			$title = $elems[$i]->as_text;
			(my $first, my $rest) = split(/[.!?“]/,$text,2);
			if (length($first.$title) > 80){
				$first = substr($first,0,80-length($title))."..."
			}
			$title .= " ".$first;
			push @news, {"Title"=>$title, "URL"=>"", "Description"=>$text};
			$text = "";
			my $title = $elems[$i]->as_text;
			next;
		}
		$text .= $elems[$i]->as_text;
	} continue {
		$i++;
	}

	return \@news;
}

1;
