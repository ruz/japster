use strict;
use warnings;

package Japster::Resource;

sub new {
    my $proto = shift;
    my $self = bless {@_}, ref($proto)||$proto;
    return $self;
}

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

1;
