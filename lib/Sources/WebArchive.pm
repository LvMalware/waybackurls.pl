package Sources::WebArchive;

use JSON;
use strict;
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
    }, $self;
}

sub get_urls
{
    my ($self, $domain, $limit) = @_;
    $domain = "*.$domain" if ($self->{subdomains});
    my $filters = $self->{filters};
    my $api_url = "$self->{api_url}?url=$domain/*&output=json&collapse=urlkey";
    $api_url .= "&filter=mimetype:$filters->{include_mime}" if $filters->{include_mime};
    $api_url .= "&filter=!mimetype:$filters->{exclude_mime}" if $filters->{exclude_mime};
    $api_url .= "&filter=statuscode:$filters->{include_code}" if $filters->{include_code};
    $api_url .= "&filter=!statuscode:$filters->{exclude_code}" if $filters->{exclude_code};
    my $response = HTTP::Tiny->new()->get($api_url);
    return {} unless $response->{success};
    return $self->__filter(decode_json($response->{content}), $filters, $limit);
}

sub __filter
{
    my ($self, $json, $filters, $limit) = @_;
    my @include = split /,/, $filters->{include_exts} || "";
    my @exclude = split /,/, $filters->{exclude_exts} || "";
    my ($current, $max) = (0, $limit || @{$json} + 0);
    my @keys = qw(key timestamp url mimetype status digest length);
    return sub {
        for (my $i = $current; $i < $max; $i ++)
        {
            my $val = $json->[$i];
            my $url = $val->[2];
            my $ext = quotemeta(Sources::Utils::get_extension($url));
            next if grep(/^$ext$/, @exclude) || (@include > 0 && !grep(/^$ext$/, @include));
            $current = $i + 1;
            return { map { $keys[$_] => $val->[$_] } 0 .. @keys - 1 }
        }
        return undef;
    }
}

1;