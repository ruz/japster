use strict;
use warnings;
use v5.10;

$SIG{KILL} = $SIG{HUP} = $SIG{TERM} = $SIG{QUIT} = sub {
    use Carp;
    print STDERR Carp::longmess(shift);
    exit;
};

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
    return deferred->resolve(
        $MyApp::Model::Tag::TAGS{ $args{id} }
    )->promise;
}

sub find {
    return deferred->resolve(
        [ map $MyApp::Model::Tag::TAGS{$_}, sort keys %MyApp::Model::Tag::TAGS ],
    )->promise;
}

sub remove {
    my $self = shift;
    my %args = @_;
    delete $MyApp::Model::Tag::TAGS{ $args{id} } or $self->exception('not_found');
    return deferred->resolve->promise;
}

sub create {
    my $self = shift;
    my %args = @_;
    return deferred->resolve(
        MyApp::Model::Tag->create( %{ $args{fields} } )
    )->promise;
}

sub update {
    my $self = shift;
    my %args = @_;
    return deferred->resolve(
        $MyApp::Model::Tag::TAGS{ $args{id} }->update( %{ $args{fields} } )
    )->promise;
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

sub update {
    my $self = shift;
    %$self = (%$self, @_);
    return $self;
}

package main;
use Data::Dumper;

use Module::Loaded qw(mark_as_loaded);
mark_as_loaded('MyApp::Model::Tag');
mark_as_loaded('MyApp::Resource::Tag');
Japster->register_resource('MyApp::Resource::Tag');

note "get tags, no so far";
Japster::Test->check_success_request(
    uri => '/tags',
    expected => {
        data => [],
        links => { self => '/tags' },
    },
);

note "get not existing tag";
Japster::Test->check_error_request(
    uri => '/tags/1',
    expected_status => 404,
);

note "create a tag";
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

note "get a tag";
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

note "get list of tags";
Japster::Test->check_success_request(
    uri => '/tags',
    expected => {
        data => [
            {
                'type' => 'tags',
                'id' => '1',
                'attributes' => {
                    'name' => 'back',
                },
                'links' => {
                    'self' => '/tags/1',
                },
            },

        ],
        links => { self => '/tags' },
    },
);

note "update a tag";
Japster::Test->check_success_request(
    method => 'PATCH',
    uri => '/tags/1',
    json => {
        "data" => {
            "type" => "tags",
            "id" => "1",
            "attributes" => {
                "name" => "front",
            },
        },
    },
    expected => {
        'data' => {
            'type' => 'tags',
            'id' => '1',
            'attributes' => {
                'name' => 'front',
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

note "get a tag after update";
Japster::Test->check_success_request(
    uri => '/tags/1',
    expected => {
        'data' => {
            'type' => 'tags',
            'id' => '1',
            'attributes' => {
                'name' => 'front',
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

note "delete a tag";
Japster::Test->check_success_request(
    method => 'DELETE',
    uri => '/tags/1',
    expected_status => 204,
);

Japster::Test->check_error_request(
    method => 'DELETE',
    uri => '/tags/1',
    expected_status => 404,
);

Japster::Test->check_error_request(
    uri => '/tags/1',
    expected_status => 404,
);

Japster::Test->check_success_request(
    uri => '/tags',
    expected => {
        data => [],
        links => { self => '/tags' },
    },
);

done_testing;
