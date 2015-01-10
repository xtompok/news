#!/usr/bin/perl

use common::sense;
use WWW::Mechanize;
use HTML::TreeBuilder;
use HTML::TableExtract qw(tree);
use URI;
use Getopt::Long;
use Hippo::HTML;

use Data::Dumper;

my $verbosity = 2;
my $cfg_file = "news.cfg";
my $out_type = "term";
my $item_limit = 10;
my $with_desc = 0;

binmode(STDOUT,":utf8");

Getopt::Long::Configure("bundling");

my $res = GetOptions ("config=s" => \$cfg_file, 
	"output:s" => \$out_type,
	"verbosity:i" => \$verbosity,
	"limit:i" => \$item_limit,
	"desc" => \$with_desc);

if ($verbosity > 2){
	print "Config file: $cfg_file\n";
	print "Output type: $out_type\n";
	print "Verbosity: $verbosity\n";
}

sub dprint {
	print @_ if ($verbosity >=5);
}

sub parse_config($){
	my $filename = $_[0];
	my @sites;
	my $site;
	open my $file,"<:utf8",$filename or die "Unable to open $filename\n";
	while (<$file>){
		chomp;
		next if (/^#/);
		my ($key,$value) = split(/:/,$_,2);
		($key) = $key =~ /^\s*([^\s]+)/;
		next if not defined $key;

		($value) = $value =~ /^\s*(.+?)\s*$/;
		
		dprint("Key: $key\n");
		dprint("Value: $value\n");


		if ($key eq "Site"){
			push @sites, $site if defined $site->{$key};
			die if not defined $value;
			$site = {};
		}
		$site->{$key} = $value;

	}
	push @sites, $site if defined $site->{Site};
	
	dprint Dumper(\@sites);
	return \@sites;
}

sub print_console{
	my $allnews = $_[0];
	while ((my $title, my $news) = each %{$allnews}){
		print "$title:\n";
		print "-" x (length($title)+1)."\n";
		my $count = 0;
		while ((my $item = $$news[$count])and(($count<$item_limit)or($item_limit==0))){
			print " - $item->{Title}\n";
			print $item->{Description}."\n" if $with_desc;
			$count++;
		}
		print "\n";
	}
}

sub print_html{
	my $allnews = $_[0];
	my @html = ();
	my @keys = sort keys %{$allnews};
	foreach my $title (@keys){
		push @html,['h4',$title];
		my @html_items = ('ul');
		my $count = 0;
		my $news = $allnews->{$title};
		while ((my $item = $$news[$count])and(($count<$item_limit)or($item_limit==0))){
			if ($item->{URL} ne ""){
				push @html_items, [ 'li',{_flat => 1},
					['a', {href=>$item->{URL}},$item->{Title}]
					];
			}else{
				push @html_items, [ 'li',{_flat => 1},$item->{Title}];
			}
			push @html_items, ['p',$item->{Description}] if $with_desc;
			$count++;
		}
		push @html, \@html_items;
	}
	my $hippo = Hippo::HTML->new(["html",
		["head",
			['meta',{http_equiv => "content-type", 
				content => "text/html;charset = UTF-8"}],
			['meta', {charset => "UTF-8"}],
			['title', 'Co je kde nového']
		],
		["body",@html]]);
	$hippo->render(\*STDOUT,0);
}

my $sites;
$sites = parse_config($cfg_file);

my %all_news;
foreach my $site (@$sites){
	dprint "Site: $site->{Site}, Module: $site->{Module}, URL: $site->{URL} \n";
	require $site->{Module};
	my $news = get_news($site->{URL});
	if (not $news){
		dprint "Failed to download news $site->{Site} from $site->{URL}";
	} else {
		$all_news{$site->{Site}}= $news;
	}
}

if ($out_type eq "term"){
	print_console(\%all_news);
} elsif ($out_type eq "html"){
	print_html(\%all_news);
}

exit;

