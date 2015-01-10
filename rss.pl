use common::sense;
use LWP::Simple;
use XML::RSS::Parser::Lite;

sub get_news($){
	my $url = $_[0];
	my $xml = get($url);
	my $rp = new XML::RSS::Parser::Lite;
	$rp->parse($xml);
	
	my @news = ();
	for (my $i = 0; $i < $rp->count(); $i++){
		my $it = $rp->get($i);
		push @news, {"Title"=>$it->get('title'), 
			"URL"=>$it->get('url'), 
			"Description"=>$it->get('description')};
	}
	return \@news;
}

1;
