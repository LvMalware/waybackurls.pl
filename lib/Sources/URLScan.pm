package Sources::URLScan;

use strict;
use warnings;
use Sources::Utils;
use Mojo::UserAgent;

sub new {
    my ($self, %args) = @_;
    bless {
        api_url => "https://urlscan.io/api/v1/search/",
        filters => {
            include_exts => $args{include_exts},
            exclude_exts => $args{exclude_exts},
            include_mime => $args{include_mime} || [],
            exclude_mime => $args{exclude_mime} || [],
            include_code => $args{include_code},
            exclude_code => $args{exclude_code},
        },
        subdomains => $args{subdomains} || 0,
        credentials => $args{credentials},
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

    my @include = split /,/, $self->{filters}->{include_exts} || "";
    my @exclude = split /,/, $self->{filters}->{exclude_exts} || "";
    my @badcodes = split /\|/, $self->{filters}->{exclude_code} || "";
    my @goodcodes = split /\|/, $self->{filters}->{include_code} || "";

    my $after = '';
    my $headers = $self->{credentials} ? { 'API-Key' => $self->{credentials}->{api_key} } : {};
    my $results = [];
    my $has_more = 1;

    my $total = 0;

    return sub {
        return undef if ($limit && $total >= $limit);

        while ($has_more || $results->@*) {
            unless ($results->@*) {
                return undef unless $has_more;
                my $api_url = "$self->{api_url}?q=domain:$domain&size=100&search_after=$after";
                my $response = $self->agent->get( $api_url => $headers )->result;
                return undef unless $response->is_success;
                $results = $response->json->{results};
                $has_more = $response->json->{has_more};
            }

            my $res = shift $results->@*;

            ($after) = grep(/\D/, $res->{sort}->@*) unless ($results->@* > 0);

            next if $res->{page}->{domain} ne $domain && !$self->{subdomains};

            my $entry = {
                url => $res->{page}->{url},
                status => $res->{page}->{status},
                length => $res->{stats}->{dataLength},
                mimetype => $res->{page}->{mimeType},
                timestamp => $res->{task}->{time},
            };

            my $ext = quotemeta(Sources::Utils::get_extension($entry->{url}));
            next if grep(/^$ext$/i, @exclude) || (@include > 0 && !grep(/^$ext$/, @include));
            next if grep($entry->{mimetype}, $self->{filters}->{exclude_mime}->@*);
            next if $self->{filters}->{include_mime}->@* && !grep($entry->{mimetype}, $self->{filters}->{include_mime}->@*);
            next if @badcodes > 0 && grep($entry->{status}, @badcodes);
            next if @goodcodes > 0 && !grep($entry->{status}, @goodcodes);

            $total ++;

            return $entry;
        }
        undef
    }
}

1;
