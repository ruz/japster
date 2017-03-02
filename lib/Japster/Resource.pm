use strict;
use warnings;

package Japster::Resource;
use base 'Japster::Base';

__PACKAGE__->register_exceptions(
    "not_implemented" => {
        "status" => "403",
        "title" =>  "Not implemented",
        "message" => "This operation is not implemented",
    },
);

sub type {
    my $self = shift;
    die "resource $self has no type defined";
}

sub id {
    my $self = shift;
    my %args = @_;
    return $args{model}->id . "";
}

sub attributes { return {} }

sub relationships { return {} }

sub load {
    die shift->exception('not_implemented', method => 'load');
}

sub find {
    die shift->exception('not_implemented', method => 'find');
}

sub create {
    die shift->exception('not_implemented', method => 'create');
}

1;
