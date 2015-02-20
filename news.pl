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
my $show_sites_str = "";

binmode(STDOUT,":utf8");

sub usage{
	print "Usage: $0 [--config | -c FILE] [--output | -o <html|term>] [--verbosity|-v VERBOSITY] [-d | --desc] [-s | --sites <site1,site2,...>] [-h | --help]\n";
	exit 1;
}

sub help{
	print <<AMEN ;
"Usage: $0 [--config | -c FILE] [--output | -o <html|term>] [--verbosity|-v VERBOSITY] 
  [-d | --desc] [-h | --help]"
	-c, --config	Configuration file
	-o, --output	Output format (HTML or terminal)
	-v, --verbosity	Verbosity
	-d, --desc	Print with description, not only titles
	-s, --sites	Print only specified comma separated sites, using Short as a key
	-h, --help	Print this help
AMEN
	exit 0;
}

Getopt::Long::Configure("bundling");

my $res = GetOptions ("config|c=s" => \$cfg_file, 
	"output|o:s" => \$out_type,
	"verbosity|v:i" => \$verbosity,
	"limit|l:i" => \$item_limit,
	"desc|d" => \$with_desc,
	"sites|s:s" => \$show_sites_str,
	"help|h" => \&help,
	"<>" => \&usage);

my %show_sites;
foreach my $site (split /,/,$show_sites_str){
	$show_sites{$site}="";
} 

if ($verbosity > 2){
	print "Config file: $cfg_file\n";
	print "Output type: $out_type\n";
	print "Verbosity: $verbosity\n";
	print "Sites: ",keys(%show_sites),"\n";
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
		
		if ($verbosity >=6){
			print("Key: $key\n");
			print("Value: $value\n");
		}


		if (($key eq "Site") and
			(defined $site->{Site}) and 
			((keys(%show_sites)==0) or 
			(exists $show_sites{$site->{Short}}))){
			push @sites, $site;
			die if not defined $value;
			$site = {};
		}
		$site->{$key} = $value;

	}
	if ((defined $site->{Site}) and 
		((keys(%show_sites)==0) or 
		(exists $show_sites{$site->{Short}}))){
		push @sites, $site;
	}
	
	dprint Dumper(\@sites);
	return \@sites;
}

sub print_console{
	my $allnews = $_[0];
	my @keys = sort keys %{$allnews};
	foreach my $title (@keys){
		print "$title:\n";
		print "-" x (length($title)+1)."\n";
		my $count = 0;
		my $news = $allnews->{$title};
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
	dprint "Site: $site->{Site}, Module: $site->{Module}, URL: $site->{URL}, Short: $site->{Short} \n";
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

