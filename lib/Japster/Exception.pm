use strict;
use warnings;
use v5.16;

package Japster::Exception;
use mro;

our %INFO;
our $JSON;
our %FORMATTERS = (
    default => sub {
        my $self = shift;
        $JSON ||= JSON->new->utf8;
        my ($status, $code, $title, $detail, $meta, $about, $pointer, $parameter) = (
            $self->status,

            $self->code,

            $self->title,
            $self->detail,
            $self->meta,
            $self->about,

            $self->pointer,
            $self->parameter,
        );
        $status ||= 500;

        my %res = ( status => "$status" );
        $res{code} = "$code" if defined $code;
        $res{title} = "$title" if defined $title;
        $res{detail} = "$detail" if defined $detail;
        $res{meta} = $meta if defined $meta;
        $res{links}{about} = $about if defined $about;
        $res{source}{pointer} = $pointer if defined $pointer;
        $res{source}{parameter} = $parameter if defined $parameter;

        return [
            $status,
            ['content-type' => 'application/json; charset=UTF-8'],
            [ $JSON->encode({errors => [\%res]}) ],
        ];
    },
);


__PACKAGE__->register(
    __PACKAGE__,
    required => { status => 500, title => 'Internal server error'},
    invalid => { status => 500, title => 'Internal server error'},
);

sub new {
    my $proto = shift;
    my $self = bless {@_}, ref($proto)||$proto;
    return $self->init;
}

sub init {
    my $self = shift;

    use Carp;
    $self->{bt} = Carp::longmess("wtf");

    my $code = $self->{code} || die $self->new( code => 'required', class => __PACKAGE__, field => 'code' );
    unless ( $INFO{$code} ) {
        warn "No registered exception code '$code' for any class";
        $self->{status} ||= 500;
        return $self;
    }

    my $class = $self->{class} || die $self->new( code => 'required', class => __PACKAGE__, field => 'class' );
    if ( my $info = $INFO{ $code }{ $class } ) {
        $self->{$_} //= $info->{$_} foreach keys %$info;
        $self->{status} ||= 500;
        return $self;
    }

    foreach my $c ( @{  mro::get_linear_isa( $class ) } ) {
        next unless my $info = $INFO{ $code }{ $c };

        $INFO{ $code }{ $class } = $info;
        $self->{$_} //= $info->{$_} foreach keys %$info;
        $self->{status} ||= 500;
        return $self;
    }
    die $self->new( code => 'invalid', class => __PACKAGE__, field => "$code in $class" );
}

sub register {
    my $self = shift;
    my $class = shift;
    my %exceptions = @_;
    while ( my ($code, $data) = each %exceptions ) {
        $data->{code} = $code;
        foreach my $c ( @{ mro::get_linear_isa( ref $class || $class ) } ) {
            $INFO{ $code }{ $c } ||= $data;
        }
    }
}

sub add_formatter {
    my $self = shift;
    my ($name, $cb) = @_;
    $FORMATTERS{ $name } = $cb;
    return $self;
}

sub format {
    my $self = shift;
    my $format = $self->{format} || 'default';
    my $formatter = $FORMATTERS{ $format }
        or die $self->new( code => 'invalid', class => __PACKAGE__, field => "$format" );

    return $formatter->($self);
}

sub status { shift->{status} }

sub code { shift->{code} }

sub title { shift->{title} }
sub detail { shift->{detail} }
sub meta { shift->{meta} }
sub about { shift->{about} }

sub pointer { shift->{pointer} }
sub parameter { shift->{parameter} }

1;
