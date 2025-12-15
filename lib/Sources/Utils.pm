package Sources::Utils;

use strict;
use warnings;
use URI::URL;

sub get_extension {
    my ($url) = @_;
    my $path = URI::URL->new($url)->epath || return '.';
    my $file = (split /\//, (split /\?|#/, $path)[0])[-1] || "";
    $file =~ /\./ ? ((split /\./, $file)[-1] || '.') : '.';
}

sub random_useragent {
    my @systems = ( 'X11; U; Linux x86_64', 'Linux; Android 5.0.1', 'Macintosh; Intel Mac OS X 10_10_1', 'iPad; CPU OS 7_1_2 like Mac OS X', 'Windows NT 6.3; WOW64' );
    my @engines = ( 'AppleWebKit/537.36 Safari', 'Chrome', 'Gecko/20100101 Firefox', 'AppleWebKit/537.36 (KHTML, like Gecko) Chrome' );

    my $system = $systems[rand(@systems)];
    my $engine = $engines[rand(@engines)];
    my $version = sprintf("%.2f", rand(200));

    "Mozilla/5.0 ($system) $engine/$version"
}

1;
