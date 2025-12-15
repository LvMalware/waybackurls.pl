package Sources::WebArchive;

use strict;
use warnings;
use Sources::Utils;
use Mojo::UserAgent;
use Mojo::JSON 'decode_json';

sub new {
    my ($self, %args) = @_;
    bless {
        api_url => "http://web.archive.org/cdx/search/cdx",
        filters => {
            include_mime => $args{include_mime} || [],
            exclude_mime => $args{exclude_mime} || [],
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
    my $api_url = "$self->{api_url}?url=$domain/*&output=json&collapse=urlkey";
    $self->__filter($self->__pages($api_url), $limit)
}

sub __pages {
    my ($self, $api_url) = @_;
    my $page = 0;
    return sub {
        my $response = $self->agent->get("$api_url&pageSize=100&page=$page")->result;
        return undef unless $response->is_success;
        $page ++;
        $response->json || [ map { decode_json($_) } split ",\n", $response->body ]
    };
}

sub __filter {
    my ($self, $next, $limit) = @_;
    my @keys = qw(key timestamp url mimetype status digest length);
    my @include = split /,/, $self->{filters}->{include_exts} || "";
    my @exclude = split /,/, $self->{filters}->{exclude_exts} || "";
    my @badcodes = split /\|/, $self->{filters}->{exclude_code} || "";
    my @goodcodes = split /\|/, $self->{filters}->{include_code} || "";

    my $total = 0;

    my $results = [];

    return sub {
        while (!defined($limit) || $total < $limit) {
            unless ($results->@* > 0) {
                unless (defined($results = $next->())) {
                    $limit = 0;
                    last;
                }
            }

            my $val = shift $results->@* || next;
            my $entry = { map { $keys[$_] => $val->[$_] } 0 .. @keys - 1 };
            next if $entry->{url} eq 'original';

            my $ext = quotemeta(Sources::Utils::get_extension($entry->{url}));
            next if grep(/^$ext$/i, @exclude) || (@include > 0 && !grep(/^$ext$/, @include));
            next if grep($entry->{mimetype}, $self->{filters}->{exclude_mime}->@*);
            next if $self->{filters}->{include_mime}->@* && !grep($entry->{mimetype}, $self->{filters}->{include_mime}->@*);
            next if @badcodes > 0 && grep($entry->{status}, @badcodes);
            next if @goodcodes > 0 && !grep($entry->{status}, @goodcodes);

            $total ++;
            return $entry
        }
        undef
    }
}

1;
