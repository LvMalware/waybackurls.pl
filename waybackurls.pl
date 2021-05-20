#!/usr/bin/env perl

use JSON;
use strict;
use warnings;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case);
use lib './lib';
use Sources::WebArchive;
use Sources::AlienVault;
use Sources::IntelligenceX;

my ($output, $silent, $json);

my @sources = qw(Sources::WebArchive Sources::AlienVault Sources::IntelligenceX);

sub search_urls
{
    my ($domain, $subdomains, $exclude_mime, $include_mime, $exclude_code,
        $include_code, $exclude_exts, $include_exts, $credentials) = @_;
    my $count = 0;
    for my $source (@sources)
    {
        my $name = (split /:/, $source)[-1];
        print STDERR "[+] Searching with $name ...\n" unless $silent;
        my $searcher = $source->new(
            include_mime => $include_mime,
            exclude_mime => $exclude_mime,
            include_exts => $include_exts,
            exclude_exts => $exclude_exts,
            include_code => $include_code,
            exclude_code => $exclude_code,
            subdomains => $subdomains,
            credentials => $credentials->{$name},
        );
        
        my $next = eval { $searcher->get_urls($domain) };
        unless (defined($next))
        {
            print STDERR "[-] Failed: $@\n" unless $silent;
            next
        }
        while (defined(my $entry = $next->()))
        {
            print $output ($json ? encode_json($entry) : $entry->{url}), "\n";
            $count ++;
        }
    }
    $count;
}

sub help
{
    my ($full) = @_;
    
    my $prog = basename($0);

    print <<HELP;
$prog - Search for urls of (sub)domains using the web archive database

Usage: $prog [option(s)] <domain_1> <domain_2> ... <domain_n>

Options:

    -h, --help              Show this help message and exit
    -v, --version           Show program version and exit
    -s, --silent            Do not show status messages
    -j, --json              Output the urls in JSON format
    -e, --extensions        Comma-separated list of extensions to filter by
    -m, --mime-types        Comma-separated list of mime-types to filter by
    -c, --status-codes      Comma-separated list of status codes to filter by
    -i, --input-file        Read list of domains from file
    -d, --subdomains        Also search for subdomain urls (default)
    -o, --output-file       Save output to a file, don't print to stdout
    -E, --exclude-exts      Comma-separated list of extensions to be ignored
    -M, --exclude-types     Comma-separated list of mime-types to be ignored
    -C, --exclude-codes     Comma-separated list of status codes to be ignored
    -g, --images            Include image links
    -k, --credentials       JSON file with credentials/API keys for sources
    --no-subdomains         Don't search for subdomain urls
    --no-images             Don't include image links (default)

HELP

    exit unless $full;
    
    print <<NOTES;

Examples:

    $prog -o output.txt -E css,js,pdf,doc,docx -C 404 targetsite.com
    $prog --no-subdomains -e php,txt,bkp -c 200 --json -i targets.txt
    $prog -o output.txt -C 404,403,500 -i - < targets.txt
    $prog -M text/html,image/jpeg,text/css targetsite.com --json > output.txt

Author:

    Lucas V. Araujo <lucas.vieira.ar\@disroot.org>
    GitHub: https://github.com/LvMalware/waybackurls.pl
    
    This tool is based on https://github.com/original
NOTES
    exit 0;
}

sub version
{
    print "v0.1.2\n";
    exit 0;
}

sub load_credentials
{
    my ($file) = @_;
    return {} unless $file;
    open(my $fh, "<$file") || die "$0: Can't open $file for reading: $!";
    decode_json(join '', <$fh>);
}

sub main
{
    my (@good_extensions, @bad_extensions, @targets);
    my (@good_types, @bad_types, @good_status, @bad_status);
    my ($subdomains, $infile, $outfile, $images) = (1, "", "", 0);
    my $img_extensions = "svg,jpg,jpeg,png,gif,ico,bmp,webp";
    my $creds_file;

    help unless @ARGV;

    GetOptions(
        "h|help"            => \&help,
        "v|version"         => \&version,
        "s|silent"          => sub { $silent = 1 },
        "j|json"            => \$json,
        "e|extensions=s"    => \@good_extensions,
        "m|mime-types=s"    => \@good_types,
        "c|status-codes=s"  => \@good_status,
        "i|input-file=s"    => \$infile,
        "d|subdomains!"     => \$subdomains,
        "o|output-file=s"   => \$outfile,
        "E|exclude-exts=s"  => \@bad_extensions,
        "M|exclude-types=s" => \@bad_types,
        "C|exclude-codes=s" => \@bad_status,
        "g|images!"         => \$images,
        "k|credentials=s"   => \$creds_file,
    ) || help();

    push @targets, @ARGV if @ARGV;

    if ($infile)
    {
        my $input;
        if ($infile eq "-")
        {
            open($input, "<&=STDIN");
        }
        else
        {
            open($input, "<$infile") ||
                die "$0: Can't open $infile: $!";
        }

        until (eof($input))
        {
            chomp(my $domain = <$input>);
            push @targets, $domain if $domain;
        }
    }
    
    die "No targets" unless @targets;
    
    open($output, ">&STDOUT");
    
    if ($outfile && $outfile ne "-")
    {
        open($output, ">$outfile") || die "$0: Can't open $outfile: $!";
    }

    my $exclude_exts = join ',', @bad_extensions;
    my $include_exts = join ',', @good_extensions;
    my $exclude_mime = join '|', map { $_ =~ s/,/\|/gr } @bad_types;
    my $include_mime = join '|', map { $_ =~ s/,/\|/gr } @good_types;
    my $exclude_code = join '|', map { $_ =~ s/,/\|/gr } @bad_status;
    my $include_code = join '|', map { $_ =~ s/,/\|/gr } @good_status;

    $exclude_exts .= "," . $img_extensions unless $images;
    for my $domain (@targets)
    {
        print STDERR "[+] Searching urls for $domain ...\n" unless $silent;
        my $total = search_urls(
            $domain, $subdomains, $exclude_mime,
            $include_mime, $exclude_code, $include_code,
            $exclude_exts, $include_exts, load_credentials($creds_file)
        );
        print STDERR "[+] Found $total valid urls.\n" unless $silent;
    }

    0;
}

exit main unless caller;

1;
