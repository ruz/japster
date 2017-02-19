use strict;
use warnings;

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

sub find {
    return deferred->resolve({
        data => [ keys %MyApp::Model::Tag::TAGS ],
    })->promise;
}

package MyApp::Model::Tag;

our %TAGS;

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

done_testing;
