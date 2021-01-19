#!/usr/bin/env perl

use utf8;
use JSON;
use strict;
use warnings;
use URI::URL;
use HTTP::Tiny;
use File::Basename;
use Getopt::Long qw(:config no_ignore_case);

my ($output, $silent, $json);

sub request
{
    my ($url) = @_;
    my $http = HTTP::Tiny->new();
    my $resp = $http->get($url);
    $resp->{success} ? $resp->{content} : ""
}

sub wayback_urls
{
    my ($domain, $subs, $bad_mime, $good_mime, $bad_status, $good_status) = @_;
    my $api_url  = "http://web.archive.org/cdx/search/cdx?url=";
    $api_url .= "*." if $subs;
    $api_url .= "$domain/*&output=json&collapse=urlkey";
    $api_url .= "&filter=!statuscode:$bad_status" if $bad_status;
    $api_url .= "&filter=statuscode:$good_status" if $good_status;
    $api_url .= "&filter=!mimetype:$bad_mime"     if $bad_mime;
    $api_url .= "&filter=mimetype:$good_mime"     if $good_mime;
    
    my $str_json = request($api_url);
    $str_json ? decode_json($str_json) : [];
}

sub get_ext
{
    my ($path) = @_;
    my $file = basename($path);
    ($file =~ /\./) ? (split /\./, $file)[-1] : '.'
}

sub filter_urls
{
    my ($urls, $include_ext, $exclude_ext) = @_;

    my $url_count = 0;

    my @bad_exts  = split /,/, $exclude_ext;
    my @good_exts = split /,/, $include_ext;
    
    for my $info (@{$urls})
    {
        my ($key, $time, $url, $type, $status, $digest, $length) = @{$info};
        
        next if $url eq 'original';
        
        my $uri = URI::URL->new($url);
        my $ext = get_ext($uri->epath);
        
        next if @good_exts && !grep(/^$ext$/i, @good_exts);
        next if @bad_exts && grep(/^$ext$/i, @bad_exts);

        $url_count ++;

        if ($json)
        {
            my $encoded = encode_json(
                {
                    url         => $url,
                    timestamp   => $time,
                    mimetype    => $type,
                    status      => $status,
                    length      => $length,
                }
            );
            print $output $encoded . "\n";
        }
        else
        {
            print $output $url . "\n";
        }
    }

    $url_count;
}

sub help
{
    my ($resumed) = @_;
    
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
    -d, --subdomains        Also search for subdomain urls (Default)
    -o, --output-file       Save output to a file, don't print to stdout
    -E, --exclude-exts      Comma-separated list of extensions to be ignored
    -M, --exclude-types     Comma-separated list of mime-types to be ignored
    -C, --exclude-codes     Comma-separated list of status codes to be ignored
    --no-subdomains         Don't search for subdomain urls

HELP

    return if $resumed;
    
    print <<NOTES;

NOTES

    exit 0;
}

sub version
{
    print "v0.1-BETA\n";
    exit 0;
}

sub main
{
    my (@good_extensions, @bad_extensions, @targets);
    my (@good_types, @bad_types, @good_status, @bad_status);
    my ($subdomains, $input_file, $output_file) = (1, "", "");

    help unless @ARGV;

    GetOptions(
        "h|help"            => \&help,
        "v|version"         => \&version,
        "s|silent"          => sub { $silent = 1 },
        "j|json"            => \$json,
        "e|extensions=s"    => \@good_extensions,
        "m|mime-types=s"    => \@good_types,
        "c|status-codes=s"  => \@good_status,
        "i|input-file=s"    => \$input_file,
        "d|subdomains!"     => \$subdomains,
        "o|output-file=s"   => \$output_file,
        "E|exclude-exts=s"  => \@bad_extensions,
        "M|exclude-types=s" => \@bad_types,
        "C|exclude-codes=s" => \@bad_status,
    ) || help();

    push @targets, @ARGV if @ARGV;
    if ($input_file)
    {
        my $input;
        if ($input_file eq "-")
        {
            open($input, "<&=STDIN");
        }
        else
        {
            open($input, "<$input_file") ||
                die "$0: Can't open $input_file: $!";
        }

        until (eof($input))
        {
            chomp(my $domain = <$input>);
            push @targets, $domain if $domain;
        }
    }
    
    die "No targets" unless @targets;
    
    open($output, ">&STDOUT");
    if ($output_file)
    {
        if ($output_file ne "-")
        {
            open($output, ">$output_file") ||
                die "$0: Can't open $output_file: $!";
        }
    }

    my $exclude_exts = join ',', @bad_extensions;
    my $include_exts = join ',', @good_extensions;
    my $exclude_mime = join '|', map { $_ =~ s/,/\|/gr } @bad_types;
    my $include_mime = join '|', map { $_ =~ s/,/\|/gr } @good_types;
    my $exclude_code = join '|', map { $_ =~ s/,/\|/gr } @bad_status;
    my $include_code = join '|', map { $_ =~ s/,/\|/gr } @good_status;

    for my $domain (@targets)
    {
        print STDERR "[+] Searching urls for $domain ...\n" unless $silent;
        my $raw_urls = wayback_urls(
            $domain, $subdomains, $exclude_mime,
            $include_mime, $exclude_code, $include_code
        );
        my $count = 0 + @{$raw_urls};
        print STDERR "[+] Got $count urls. Filtering ...\n" unless $silent;
        my $total = filter_urls($raw_urls, $include_exts, $exclude_exts);
        print STDERR "[+] Found $total valid urls.\n" unless $silent;
    }

    0;
}

exit main unless caller;

1;