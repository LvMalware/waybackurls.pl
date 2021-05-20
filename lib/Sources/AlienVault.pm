package Sources::AlienVault;

use JSON;
use strict;
use warnings;
use HTTP::Tiny;
use Sources::Utils;

sub new
{
    my ($self, %args) = @_;
    bless {
        api_url => "https://otx.alienvault.com/api/v1/indicators/",
        filters => {
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
    my $api_url = $self->{api_url} . ($self->{subdomains} ? "domain" : "hostname");
    return $self->__filter($self->__pages("$api_url/$domain/url_list"), $limit);
}

sub __pages
{
    my ($self, $api_url) = @_;
    my $page = 0;
    return sub {
        return undef if $page < 0;
        my $response = HTTP::Tiny->new()->get("$api_url?page=$page");
        my $json = $response->{success} ? decode_json($response->{content}) : {};
        $page = $json->{has_next} ? $page + 1 : -1;
        return (%{$json} + 0) ? $json->{url_list} : undef;
    }
}

sub __filter
{
    my ($self, $page, $limit) = @_;
    my ($current_page, $count) = (undef, 0);
    my ($index, $final) = (1, 0);
    my $filters = $self->{filters};
    my @include_code = split /,/, $filters->{include_code} || "";
    my @exclude_code = split /,/, $filters->{exclude_code} || "";
    my @include_exts = split /,/, $filters->{include_exts} || "";
    my @exclude_exts = split /,/, $filters->{exclude_exts} || "";
    return sub {
        while (!$limit || $count < $limit)
        {
            if ($index >= $final)
            {
                $current_page = $page->() || return undef;
                ($index, $final) = (0, @{$current_page} + 0);
            }
            my $entry = $current_page->[$index ++];
            my $code = $entry->{httpcode};
            next if grep(/^$code$/, @exclude_code) || (@include_code > 0 && !grep(/^$code$/, @include_code));
            my $url = $entry->{url};
            my $ext = quotemeta(Sources::Utils::get_extension($url));
            next if grep(/^$ext$/, @exclude_exts) || (@include_exts > 0 && !grep(/^$ext$/, @include_exts));
            $count ++;
            return { timestamp => $entry->{date}, url => $url, status => $code }
        }
        return undef
    }
}

1;