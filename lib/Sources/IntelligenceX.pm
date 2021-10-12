package Sources::IntelligenceX;

use JSON;
use strict;
use URI::URL;
use warnings;
use HTTP::Tiny;
use Sources::Utils;

sub new
{
    my ($self, %args) = @_;
    bless {
        api_url => "http://web.archive.org/cdx/search/cdx",
        filters => {
            include_mime => $args{include_mime},
            exclude_mime => $args{exclude_mime},
            include_exts => $args{include_exts},
            exclude_exts => $args{exclude_exts},
            include_code => $args{include_code},
            exclude_code => $args{exclude_code},
        },
        subdomains => $args{subdomains} || 0,
        credentials => $args{credentials},
    }, $self;
}

sub get_urls
{
    my ($self, $domain, $limit) = @_;
    my $api_key = $self->{credentials}->{api_key} || die "Missing API key";
    my $api_url = "https://public.intelx.io/phonebook/search?k=$api_key";
    my $post_data = qq({"term":"$domain","media":0,"target":3,"terminate":[null],"timeout":20});
    my $response = HTTP::Tiny->new()->post($api_url, { content => $post_data });
    my $json = $response->{success} ? decode_json($response->{content}) : {};
    my $search_id = $json->{id} || die "Search error";
    my $result_url = "https://public.intelx.io/phonebook/search/result?k=$api_key&id=$search_id";
    my $next = $self->__results($result_url);
    return $self->__filter($next, $limit, $domain);
}

sub __results
{
    my ($self, $result_url) = @_;
    return sub {
        my $response = HTTP::Tiny->new()->get($result_url);
        my $json = $response->{success} ? decode_json($response->{content}) : {};
        return @{$json->{selectors}} > 0 ? $json->{selectors} : undef
    }
}

sub __filter
{
    my ($self, $next, $limit, $domain) = @_;
    my ($current, $count) = (undef, 0);
    my ($index, $final) = (1, 0);
    my $filters = $self->{filters};
    my @include = split /,/, $filters->{include_exts} || "";
    my @exclude = split /,/, $filters->{exclude_exts} || "";
    return sub {
        while (!$limit || $count < $limit)
        {
            if ($index >= $final)
            {
                $current = $next->() || return undef;
                ($index, $final) = (0, @{$current} + 0);
            }
            my $entry = $current->[$index ++];
            my $url = $entry->{selectorvalue};
            my $ext = quotemeta(Sources::Utils::get_extension($url));
            next if grep(/^$ext$/i, @exclude) || (@include > 0 && !grep(/^$ext$/, @include));
            my $host = URI::URL->new($url)->host;
            next if !($self->{subdomains}) && $host ne $domain;
            return { url => $url }
        }
    }
}

1;
