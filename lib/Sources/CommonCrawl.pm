package Sources::CommonCrawl;

use JSON;
use strict;
use warnings;
use HTTP::Tiny;
use Sources::Utils;

sub new {
    my ($self, %args) = @_;
    bless {
        api_url => "https://index.commoncrawl.org/collinfo.json",
        filters => {
            include_mime => $args{include_mime},
            exclude_mime => $args{exclude_mime},
            include_exts => $args{include_exts},
            exclude_exts => $args{exclude_exts},
            include_code => $args{include_code},
            exclude_code => $args{exclude_code},
        },
        subdomains => $args{subdomains} || 0,
    }, $self;
}

sub get_urls
{
    my ($self, $domain, $limit) = @_;
    my $http = HTTP::Tiny->new();
    $domain = "*.$domain" if ($self->{subdomains});
    my $filters = $self->{filters};
    my $indexes = decode_json($http->get($self->{api_url})->{content});
    my $query   = "?url=$domain/*&output=json&collapse=urlkey";
    $query .= "&filter=mimetype:$filters->{include_mime}" if $filters->{include_mime};
    $query .= "&filter=!mimetype:$filters->{exclude_mime}" if $filters->{exclude_mime};
    $query .= "&filter=statuscode:$filters->{include_code}" if $filters->{include_code};
    $query .= "&filter=!statuscode:$filters->{exclude_code}" if $filters->{exclude_code};
    return $self->__filter($self->__indexes($indexes, $query), $limit);
}

sub __indexes {
    my ($self, $list, $query) = @_;
    my $http = HTTP::Tiny->new();
    my $index = 0;
    return sub {
        return "" if $index > $#$list;
        my $entry = $list->[$index ++];
        $http->get($entry->{'cdx-api'} . $query)->{content};
    }
}

sub __filter
{
    my ($self, $next, $limit) = @_;
    my @include = split /,/, $self->{filters}->{include_exts} || "";
    my @exclude = split /,/, $self->{filters}->{exclude_exts} || "";
    my @keys = qw(key timestamp url mimetype status digest length);
    my $current = 0;
    my $crawled = $next->();
    return sub {
        return undef unless $crawled;
        my $end = index($crawled, "\n", $current);
        while ($end != -1) {
            my $sub = substr($crawled, $current, $end - $current);
            $current = $end + 1;
            $end = index($crawled, "\n", $current);
            my $cur = eval { decode_json($sub) } || next;
            my $url = $cur->{url};
            my $ext = quotemeta(Sources::Utils::get_extension($url));
            next if grep(/^$ext$/i, @exclude) || (@include > 0 && !grep(/^$ext$/, @include));
            return $cur
        }
        if ($end == -1) {
            $crawled = $next->();
            $current = 0;
        }
    }
}

1;
