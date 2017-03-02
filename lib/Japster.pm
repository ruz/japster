use strict;
use warnings;
use v5.16;

package Japster;
use base 'Japster::Base';

=head1 NAME

Japster - helps setup async JSONAPI application

=cut

use Promises qw(deferred);
use Async::ContextSwitcher;
use Scalar::Util qw(blessed);
use Carp qw(confess);
use URI::Escape qw(uri_unescape);

__PACKAGE__->register_exceptions(
    "bad_relationship_operation" => {
        "status" => "403",
        "title" =>  "Forbidden",
        "message" => "This operation on this relation is not allowd",
    },
    method_not_allowed => {
        status => 405,
        title => 'Method Not Allowed',
        message => 'Requested HTTP method is not allowed',
    },
    not_found => {
        status => 404,
        title => 'Not found',
        message => 'Resource requested doesn\'t exist',
    },
);

sub init {
    my $self = shift;
    $self->{base_url} //= '/';
    $self->{base_url} .= '/' unless $self->{base_url} =~ m{/$};
    return $self;
}

my %TYPE_TO_CLASS;
my %MODEL_TO_CLASS;

sub register_resource {
    my $self = shift;
    my $class = shift;

    eval "require $class; 1" or confess "Couldn't load $class: $@";

    my $type = $class->type;
    $TYPE_TO_CLASS{ $type } = $class;
    $MODEL_TO_CLASS{ $class->model_class } = $class;
}

my %methods_map = (
    collection => {
        get => 'find_resource',
        post => 'create_resource',
    },
    resource => {
        get => 'load_resource',
        patch => 'update_resource',
        delete => 'remove_resource',
    },
    related => {
        get => 'load_related',
    },
    relationship => {
        get => 'load_relationship',
        post => 'add_relationship',
        patch => 'set_relationship',
        delete => 'remove_relationship',
    },
);

sub handle {
    my $self = shift;
    my %args = (
        env => undef,
        @_
    );
    my $env = $args{env};

    my $path = $env->{PATH_INFO};
    $path = '/' unless defined $path && length $path;
    $path =~ s{^\Q$self->{base_url}}{}
        or return undef;
    $path =~ s{/$}{};

    my ($type, $id, @rest) = split /\//, $path;
    return undef unless $type;
    return undef if defined $id && !length $id;

    my $class = $TYPE_TO_CLASS{ $type } or return undef;
    my $resource = $class->new( env => $env );

    my ($method, %method_args);
    eval {
        my $http_method = $env->{REQUEST_METHOD};
        unless ( defined $id ) {
            $method = $methods_map{collection}{lc $http_method}
                or die $self->exception('method_not_allowed');
        }
        elsif ( !@rest ) {
            $method = $methods_map{resource}{lc $http_method}
                or die $self->exception('method_not_allowed');
            %method_args = ( id => $id );
        }
        elsif ( @rest == 1 && $resource->relationships->{ $rest[0] } ) {
            $method = $methods_map{related}{lc $http_method}
                or die $self->exception('method_not_allowed');
            %method_args = ( id => $id, name => $rest[0] );
        }
        elsif (
            @rest == 2 && $rest[0] eq 'relationships'
            && $rest[1] && $resource->relationships->{ $rest[1] }
        ) {
            $method = $methods_map{relationship}{lc $http_method}
                or die $self->exception('method_not_allowed');
            %method_args = ( id => $id, name => $rest[1] );
        }
        1;
    } or return deferred->reject( $self->format_error($@) )->promise;
    return undef unless $method;

    return $self->$method(
        env => $env,
        resource => $resource,
        %method_args,
    )
    ->catch(sub {
        die $self->format_error( @_ );
    });
}

sub format {
    my $self = shift;
    my ($obj, %args) = (@_);

    my $resource;
    if ( $args{type} ) {
        $resource = $TYPE_TO_CLASS{ $args{type} }->new;
    }
    elsif ( blessed $obj ) {
        if ( $obj->isa('Japster::Resource') ) {
            $resource = $obj;
        }
        elsif ( my $class = $MODEL_TO_CLASS{ ref $obj } ) {
            $resource = $class->new;
        }
        else {
            die "'". ref($obj) ."' is neither resource or model";
        }
    }

    my %res = (
        type => $resource->type,
        id => $resource->id( model => $obj ),
    );
    $res{links} = {
        self => $self->{base_url} . $res{type} .'/'. $res{id},
    };
    my $attrs = $resource->attributes;
    while ( my ($name, $info) = each %$attrs ) {
        $res{attributes}{ $name } = $obj->$name();
    }
    my $rels = $resource->relationships;
    while ( my ($name, $info) = each %$rels ) {
        my %rel = (
            links => {
                self => $self->{base_url} . $res{type} .'/'. $res{id} . '/relationships/'. $name,
                related => $self->{base_url} . $res{type} .'/'. $res{id} . '/'. $name,
            },
        );
        if ( my $m = $resource->can("rel_${name}_embed") ) {
            $rel{data} = $m->( $resource, model => $obj );
        }
        elsif ( $info->{type} && $info->{field} ) {
            my $field = $info->{field};
            my $value = $obj->$field();
            if ( $value ) {
                $rel{data} = { type => $info->{type}, id => $value };
            } else {
                $rel{data} = undef;
            }
        }
        $res{relationships}{$name} = \%rel;
    }
    return \%res;
}

sub format_error {
    my $self = shift;

    my $err = shift;
    if ( blessed $err && $err->isa('Japster::Exception') ) {
        return $err->format;
    }
    elsif ( !ref $err ) {
        warn $err;
        return $self->exception('internal')->format;
    }
    else {
    };
    return $err;
}

sub parse_resource_from_request {
    my $self = shift;
    my %args = (
        resource => undef,
        env => undef,
        @_
    );
    my $resource = $args{resource};

    my $body = $self->request_body( $args{env} );
    die $self->exception('invalid_request') # TODO: format
        unless $body && $body->{data} && ref $body->{data} eq 'HASH';

    my $data = $body->{data};

    my %fields;
    $fields{id} = $data->{id} if exists $data->{id};

    my $attrs = $resource->attributes;
    foreach my $name ( grep exists $data->{attributes}{$_}, keys %$attrs ) {
        $fields{$name} = delete $data->{attributes}{$name};
    }
    die $self->exception(
        'unexpected_attr', fields => [keys %{ $data->{attributes} }],
    ) if $data->{attributes} && keys %{ $data->{attributes} };

    my $rels = $resource->relationships;
    foreach my $name ( grep exists $data->{relationships}{$_}, keys %$rels ) {
        my $info = $rels->{ $name };
        $fields{$name} = delete $data->{relationships}{$name};
        if ( $info->{type} && $info->{field} ) {
            # TODO: type check
            unless ( defined $fields{ $name }{data} ) {
                $fields{ $info->{field} } = (delete $fields{ $name })->{data};
            } else {
                $fields{ $info->{field} } = (delete $fields{ $name })->{data}{id};
            }
        }
    }
    die $self->exception(
        'unexpected_relationships', fields => [keys %{ $data->{relationships} }],
    ) if $data->{relationships} && keys %{ $data->{relationships} };

    return \%fields;
}

sub find_resource {
    my $self = shift;
    my %args = (
        resource => undef,
        env => undef,
        @_
    );

    my $query = $self->query_parameters( $args{env} );
    if ( $query->{sort} ) {
        my @sort;
        foreach my $e ( split /\s*,\s*/, $query->{sort} ) {
            my $order = $e =~ s/^-//? 'desc' : 'asc';
            push @sort, { by => $e, order => $order };
        }
        $query->{sort} = \@sort;
    }

    my $resource = $args{resource};
    return $resource->find( query => $query )
    ->then( sub {
        my $res = shift;
        return $self->resource_response(
            data => $res->{data},
            model => $res->{model},
            type => $resource->type,
            links => { self => $resource->type },
        );
    });
}

sub load_resource {
    my $self = shift;
    my %args = (
        resource => undef,
        id => undef,
        @_
    );
    my $resource = $args{resource};
    return $resource->load( id => $args{id} )
    ->then( cb_w_context {
        my $res = shift;
        die $self->exception('not_found') unless $res->{data} || $res->{model};
        return $self->resource_response(
            data => $res->{data},
            model => $res->{model},
            type => $resource->type,
            links => { self => $resource->type . '/'. $args{id} },
        );
    });
}

sub create_resource {
    my $self = shift;
    my %args = @_;

    my $fields = $self->parse_resource_from_request( %args );

    my $resource = $args{resource};
    return $resource->create( %args, fields => $fields )
    ->then( cb_w_context {
        my $res = shift;
        die $self->exception('internal') unless $res->{data} || $res->{model};
        my $id = $res->{data}? $res->{data}->{id} : $resource->id( model => $res->{model} );
        return $self->resource_response(
            data => $res->{data},
            model => $res->{model},
            type => $resource->type,
            links => { self => $resource->type . '/'. $id },
            status => 201,
        );
    });
}

sub update_resource {
    my $self = shift;
    my %args = @_;

    my $resource = $args{resource};
    my $fields = $self->parse_resource_from_request( %args );

    my $data = $self->request_body( $args{env} );
    return $resource->update( %args, fields => $fields )
    ->then( cb_w_context {
        my $o = shift;
        return $self->resource_response(
            data => $o,
            type => $resource->type,
            links => { self => $resource->type . '/'. $o->{id} },
        );
    });
}

sub remove_resource {
    my $self = shift;
    my %args = (
        resource => undef,
        id => undef,
        @_
    );
    my $resource = $args{resource};
    return $resource->remove( id => $args{id} )
    ->then( sub {
        my $res = shift || {};
        return $self->simple_psgi_response('no_content') unless $res->{meta};

        die 'not implemented';
    });
}

sub load_related {
    my $self = shift;
    my %args = @_;

    my $method = 'rel_'. $args{name} . '_related';
    $method =~ s/-/_/g;

    my $resource = $args{resource};
    return $resource->$method(
        id => $args{id},
    )->then( cb_w_context {
        return $self->resource_response(
            data => shift,
            links => { self => $resource->type . '/'. $args{id} .'/'. $args{name} },
        );
    });

}

sub add_relationship {
    my $self = shift;
    my %args = (
        resource => undef,
        id => undef,
        name => undef,
        info => undef,
        @_
    );

    my $resource = $args{resource};

    my $method = 'rel_'. $args{name} . '_add';
    $method =~ s/-/_/g;
    return $self->exception('bad_relationship_operation')
        unless $resource->can($method);

    my $data = $self->request_body( $args{env} );
    return $resource->$method(
        %args,
        id => $args{id},
        data => $data->{data},
    )
    ->then( cb_w_context {
        my $res = shift;
        if ( $res->{included} ) {
            $_ = $self->format($_) foreach @{ $res->{included} };
        }
        return $self->simple_psgi_response( json => $res );
    });
}

sub request_body {
    my $self = shift;
    my $env = shift;
    require Plack::Request;
    my $plackr = Plack::Request->new($env);
    use JSON;
    return JSON->new->utf8->decode( $plackr->raw_body );
}

sub query_parameters {
    my $self = shift;
    my $env = shift;

    return {} unless defined $env->{QUERY_STRING} && length $env->{QUERY_STRING};

    my @query =
        map { s/\+/ /g; uri_unescape($_) }
        map { /=/ ? split(/=/, $_, 2) : ($_ => '') }
        split /[&;]/, $env->{QUERY_STRING};

    my %res;
    while ( my ($k, $v) = splice @query, 0, 2 ) {
        unless ( $k =~ /\]$/ ) {
            $res{$k} = $v;
            next;
        }

        my @keys;
        unshift @keys, $1 while $k =~ s/\[([^\]]*)\]$//;
        unshift @keys, $k;

        my $tmp = \%res;
        do {
            $k = shift @keys;
            unless ( @keys ) {
                if ( length $k && $k =~ /[^0-9]/ ) {
                    $tmp->{$k} = $v;
                }
                elsif ( length $k ) {
                    $tmp->[$k] = $v;
                }
                else {
                    push @$tmp, $v;
                }
            }
            elsif ( length $keys[0] && $keys[0] =~ /[^0-9]/ ) {
                if ( ref $tmp eq 'HASH' ) {
                    $tmp->{$k} ||= {};
                    unless ( ref $tmp->{$k} eq 'HASH' ) {
                        $tmp->{$k} = { '' => $tmp->{$k} };
                    }
                    $tmp = $tmp->{$k};
                } else {
                    $k ||= 0;
                    $tmp->[$k] ||= {};
                    unless ( ref $tmp->[$k] eq 'HASH' ) {
                        $tmp->[$k] = { '' => $tmp->[$k] };
                    }
                    $tmp = $tmp->[$k];
                }
            }
            else {
                if ( ref $tmp eq 'HASH' ) {
                    $tmp->{$k} ||= [];
                    unless ( ref $tmp->{$k} eq 'ARRAY' ) {
                        $tmp = $tmp->{$k}{''} ||= [];
                    } else {
                        $tmp = $tmp->{$k};
                    }
                } else {
                    $k ||= 0;
                    $tmp->[$k] ||= [];
                    unless ( ref $tmp->[$k] eq 'ARRAY' ) {
                        $tmp = $tmp->[$k]{''} ||= [];
                    } else {
                        $tmp = $tmp->[$k];
                    }
                }
            }
        } while @keys;
    }
    return \%res;
}

sub resource_response {
    my $self = shift;
    my %args = (
        data => undef,
        type => undef,
        links => undef,
        status => undef,
        @_
    );

    my $e;
    if ( $args{data} ) {
        $e = $args{data};
    }
    elsif ( $args{model} ) {
        $e = $args{model};
        if ( ref $e eq 'ARRAY' ) {
            $_ = $self->format( $_, type => $args{type} ) foreach @$e;
        }
        else {
            $e = $self->format( $e, type => $args{type} );
        }
    }

    my $res = {
        links => {
            self => $self->{base_url} . $args{links}{self},
        },
        data => $e,
    };
    return $self->simple_psgi_response( $args{status}||200, json => $res );
}

1;
