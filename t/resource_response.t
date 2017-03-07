use strict;
use warnings;

use Japster::Test;
use Test::More;

use_ok('Japster');

use Module::Loaded qw(mark_as_loaded);
mark_as_loaded('MyApp::Model::Tag');
mark_as_loaded('MyApp::Resource::Tag');
Japster->register_resource('MyApp::Resource::Tag');

check(
    [undef],
    json => { data => undef },
);

check(
    [bless({id=> 1, name => 'back'}, 'MyApp::Model::Tag')],
    json => {
        data => {
            id => "1", type => "tags",
            attributes => { name => "back" },
            links => { self => '/tags/1'},
        }
    },
);

check(
    [ [] ],
    json => { data => [] },
);

check(
    [
        [
            bless({id=> 1, name => 'back'}, 'MyApp::Model::Tag'),
        ],
    ],
    json => {
        data => [
            {
                id => "1", type => "tags",
                attributes => { name => "back" },
                links => { self => '/tags/1'},
            }
        ],
    },
);

sub check {
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $data = shift;
    my %expected = @_;

    my $response = Japster->new->resource_response(
        @$data
    );
    is ref($response), 'ARRAY', 'response is an ARRAY';
    is $response->[0], 200, 'response status is correct';
    my %headers = @{ $response->[1] };
    # TODO: check headers

    my $got = JSON->new->utf8->decode(join '', @{ $response->[2] });

    use Data::Dumper;
    is_deeply($got, $expected{json})
        or diag "expected: ". Dumper($expected{json}) . "got: ". Dumper($got);
}

done_testing();

package MyApp::Resource::Tag;
use base 'Japster::Resource';
use Promises qw(deferred);

sub type { 'tags' }

sub model_class { 'MyApp::Model::Tag' }

sub attributes {
    return {
        name => {},
    };
}

package MyApp::Model::Tag;

our %TAGS;

sub id {
    return $_[0]->{id};
}

sub name {
    return $_[0]->{name};
}

