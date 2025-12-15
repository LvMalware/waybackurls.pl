package Sources::CommonCrawl;

use strict;
use warnings;
use Sources::Utils;
use Mojo::UserAgent;
use Mojo::JSON 'decode_json';

sub new {
    my ($self, %args) = @_;
    bless {
        api_url => "https://index.commoncrawl.org/CC-MAIN-2022-33-index",
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

sub agent {
    my ($self) = @_;
    $self->{agent} ||= Mojo::UserAgent->new(inactivity_timeout => 0);
    $self->{agent}->transactor->name(Sources::Utils::random_useragent);
    $self->{agent}
}

sub get_urls {
    my ($self, $domain, $limit) = @_;
    $domain = "*.$domain" if ($self->{subdomains});
    my $filters = $self->{filters};
    my $indexes = $self->agent->get($self->{api_url})->result->json;
    my $query   = "?url=$domain/*&output=json&collapse=urlkey";
    $query .= "&filter=mimetype:$filters->{include_mime}" if $filters->{include_mime};
    $query .= "&filter=!mimetype:$filters->{exclude_mime}" if $filters->{exclude_mime};
    $query .= "&filter=statuscode:$filters->{include_code}" if $filters->{include_code};
    $query .= "&filter=!statuscode:$filters->{exclude_code}" if $filters->{exclude_code};
    return $self->__filter($self->agent->get($self->{api_url} . $query)->result->body, $limit)
}

sub __filter {
    my ($self, $body, $limit) = @_;
    my @include = split /,/, $self->{filters}->{include_exts} || "";
    my @exclude = split /,/, $self->{filters}->{exclude_exts} || "";
    my @jsonobj = split /\n/, $body;
    return sub {
        while (@jsonobj > 0) {
            my $next = shift @jsonobj;
            my $json = decode_json($next);
            next unless $json->{url};
            my $ext = quotemeta(Sources::Utils::get_extension($json->{url}));
            next if grep(/^$ext$/i, @exclude) || (@include > 0 && !grep(/^$ext$/, @include));
            return $json
        }
        return undef;
    }
}

1;
