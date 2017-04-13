use strict;
use warnings;

package Japster::Resource;
use base 'Japster::Base';

__PACKAGE__->register_exceptions(
    "not_implemented" => {
        "status" => "403",
        "title" =>  "Not implemented",
        "detail" => "This operation is not implemented",
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

sub client_generated_id {
    return 0;
}

sub attributes { return {} }

sub relationships { return {} }

sub load {
    die shift->exception('not_implemented', meta => { method => 'load' } );
}

sub find {
    die shift->exception('not_implemented', meta => { method => 'find' } );
}

sub create {
    die shift->exception('not_implemented', meta => { method => 'create' } );
}

sub remove {
    die shift->exception('not_implemented', meta => { method => 'remove' } );
}

1;
