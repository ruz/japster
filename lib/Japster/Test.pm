use strict;
use warnings;

package Japster::Test;
use Test::More;
use Data::Dumper;

sub check_success_request {
    my $self = shift;
    my %args = (@_);

    my $env = $self->basic_request_env($args{uri}, %args);
    my $j = $args{japster} || Japster->new;
    return $j->handle(env => $env)
    ->then(sub {
        my $res = shift;

        is ref $res, 'ARRAY', 'an array';
        is scalar @$res, 3, 'with three elements';

        is $res->[0], $args{expected_status} || 200, 'HTTP status is 200';

        is ref $res->[2], 'ARRAY', 'an array';

        my $expected = $args{expected};
        if ( $expected ) {
            my $json = join '', @{$res->[2]};
            my $data;
            eval { $data = JSON->new->utf8->decode($json); 1 }
                or fail('is not json: '. $@);

            is_deeply($data, $expected, 'correct response')
                or diag( "got: ". Dumper($data) ."expected: ". Dumper($expected) );
        }
    })
    ->catch(sub {
        fail( "error is not expected: ". Dumper(\@_) );
    });
}

sub check_error_request {
    my $self = shift;
    my %args = (@_);

    my $env = $self->basic_request_env($args{uri});
    my $j = $args{japster} || Japster->new;
    return $j->handle(env => $env)
    ->then(sub {
        fail( "success is not expected: ". Dumper(\@_) );
    })
    ->catch(sub {
        my $res = shift;

        is ref $res, 'ARRAY', 'an array';
        is scalar @$res, 3, 'with three elements';

        is $res->[0], $args{expected_status}, 'HTTP status is '. $args{expected_status};

        is ref $res->[2], 'ARRAY', 'an array';

        my $json = join '', @{$res->[2]};
        my $data;
        eval { $data = JSON->new->utf8->decode($json); 1 }
            or fail('is not json: '. $@);

        is ref $data->{errors}, 'ARRAY', 'an array of errors';
    });
}

sub basic_request_env {
    my $self = shift;
    my $url = shift || '/';
    my %args = @_;
    my $res = {
        HTTP_ACCEPT => '*/*',
        HTTP_HOST => 'www.test.ru',
        HTTP_USER_AGENT => 'some/7.35.0',
        PATH_INFO => $url,
        QUERY_STRING => '',
        REMOTE_ADDR => '127.0.0.1',
        REMOTE_PORT => 49804,
        REQUEST_METHOD => $args{method} || 'GET',
        REQUEST_URI => $url,
        SCRIPT_NAME => '',
        SERVER_NAME => 0,
        SERVER_PORT => 5000,
        SERVER_PROTOCOL => 'HTTP/1.1',
        'psgi.errors' => \*STDERR,
        'psgi.input' => undef,
        'psgi.multiprocess' => '',
        'psgi.multithread' => '',
        'psgi.nonblocking' => '',
        'psgi.run_once' => '',
        'psgi.streaming' => 1,
        'psgi.url_scheme' => 'http',
        'psgi.version' => [
            1,
            1
        ],
        'psgix.harakiri' => 1,
        'psgix.io' => undef,
    };

    if ( my $c = delete $args{cookies} ) {
        my $str = '';
        while ( my ($name, $values) = each %$c ) {
            $str .= '; ' if $str;
            $str .= join '; ', map URI::Escape::uri_escape($name) .'='. URI::Escape::uri_escape($_),
                ref $values? @$values : ($values);
        }
        $res->{HTTP_COOKIE} = $str;
    }

    if ( $args{json} ) {
        $res->{CONTENT_TYPE} = 'application/json';
        my $buf = JSON::XS->new->pretty->utf8->encode(delete $args{json});
        $res->{CONTENT_LENGTH} = length $buf;
        open my $fh, '<:raw', \$buf;
        $res->{'psgi.input'} = $fh;
    }
    return $res;
}

1;
