use strict;
use warnings;
use v5.10;

use Japster::Test;
use Test::More;

use_ok('Japster');

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

sub load {
    my $self = shift;
    my %args = @_;
    return deferred->resolve({
        model => $MyApp::Model::Tag::TAGS{ $args{id} }
    })->promise;
}

sub find {
    return deferred->resolve({
        data => [ keys %MyApp::Model::Tag::TAGS ],
    })->promise;
}

sub create {
    my $self = shift;
    my %args = @_;
    return deferred->resolve({
        model => MyApp::Model::Tag->create( %{ $args{fields} } ),
    })->promise;
}

package MyApp::Model::Tag;

our %TAGS;

sub id {
    return $_[0]->{id};
}

sub name {
    return $_[0]->{name};
}

sub create {
    shift;
    state $i = 0;
    $i++;
    return $TAGS{$i} = bless { @_, id => $i }, __PACKAGE__;
}

package main;
use Data::Dumper;

use Module::Loaded qw(mark_as_loaded);
mark_as_loaded('MyApp::Model::Tag');
mark_as_loaded('MyApp::Resource::Tag');
Japster->register_resource('MyApp::Resource::Tag');

Japster::Test->check_success_request(
    uri => '/tags',
    expected => {
        data => [],
        links => { self => '/tags' },
    },
);

Japster::Test->check_error_request(
    uri => '/tags/1',
    expected_status => 404,
);

Japster::Test->check_success_request(
    method => 'POST',
    uri => '/tags',
    json => {
        "data" => {
            "type" => "tags",
            "attributes" => {
                "name" => "back",
            },
        },
    },
    expected_status => 201,
    expected => {
        'data' => {
            'type' => 'tags',
            'id' => '1',
            'attributes' => {
                'name' => 'back',
            },
            'links' => {
                'self' => '/tags/1',
            }
        },
        'links' => {
            'self' => '/tags/1',
        },
    },
);

Japster::Test->check_success_request(
    uri => '/tags/1',
    expected => {
        'data' => {
            'type' => 'tags',
            'id' => '1',
            'attributes' => {
                'name' => 'back',
            },
            'links' => {
                'self' => '/tags/1',
            }
        },
        'links' => {
            'self' => '/tags/1',
        },
    },
);

done_testing;
