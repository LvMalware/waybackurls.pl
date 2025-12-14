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

1;
