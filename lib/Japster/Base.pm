use strict;
use warnings;

package Japster::Base;

use Japster::Exception;
use Encode;
use JSON;
our $JSON = JSON->new->utf8;

sub new {
    my $proto = shift;
    my $self = bless {@_}, ref($proto)||$proto;
    return $self->init;
}

sub init {
    return $_[0];
}

sub exception {
    my $self = shift;
    my $code = shift;
    return Japster::Exception->new( class => ref($self) || $self, code => $code, @_ );
}

sub register_exceptions {
    my $self = shift;
    return Japster::Exception->register( $self, @_ );
}

sub simple_psgi_response {
    my $self = shift;

    my $status = 200;
    $status = shift if $_[0] && $_[0] !~ /\D/;
    my ($type, $data) = (shift, shift);

    my $headers = ref $_[0]? shift : {@_};

    my @res;
    if ($type eq 'json') {
        $headers->{'content-type'} = 'application/json; charset=UTF-8';
        $data = $JSON->encode($data);
    }
    elsif ($type eq 'text') {
        $headers->{'content-type'} = 'text/plain; charset=UTF-8';
        $data = Encode::encode_utf8($data);
    }
    elsif ($type eq 'html') {
        $headers->{'content-type'} = 'text/html; charset=UTF-8';
        $data = Encode::encode_utf8($data);
    }
    elsif ($type eq 'no_content') {
        $status = 204;
        $data = '';
    }
    else {
        die "Unknown type '$type'";
    }

    my $cache = delete $headers->{cache} // 'no';
    if ( length $cache ) {
        my $cache_headers = $self->generate_cache_headers( $cache );
        @{$headers}{ keys %$cache_headers } = values %$cache_headers;
    }

    return [ $status, [%$headers], [$data] ];
}

use constant SECONDS_IN_ONE_YEAR => 31556926;

sub generate_cache_headers {
    my $self = shift;
    my $cache = shift or return {};

    unless ( ref $cache ) {
        $cache = { for => $cache };
    }

    my $for = $cache->{for} // '';

    if ( $for eq 'no' ) {
        return {
            'cache-control' => 'no-cache, no-store, must-revalidate',
            'pragma' => 'no-cache',
            'expires' => 0,
        }
    }
    elsif ( $for eq 'forever' ) {
        $for = SECONDS_IN_ONE_YEAR; # 1 year
    }
    elsif ( $for =~ /^ (?: (\d+)M \s*)? (?: (\d+)D \s*)? (?: (\d+)h \s*)? (?: (\d+)m \s*)? (?: (\d+)s \s*)? $/x) {
        $for = int(($1//0)*30.416666667*24*60*60 + ($2//0)*24*60*60 + ($3//0)*60*60 + ($4//0)*60 + ($5//0));
    }
    elsif ( $for =~ /^[0-9]+$/ ) {
    }
    else {
        die "Invalid cache value '$for'";
    }
    $for = SECONDS_IN_ONE_YEAR if $for > SECONDS_IN_ONE_YEAR;

    my %control = ('max-age' => $for);

    my %res;
    $res{'cache-control'} = join ', ', map { $_ . (defined $control{$_} && length $control{$_}? '='.$control{$_} : '') }
        keys %control;
    return \%res;
}

1;
