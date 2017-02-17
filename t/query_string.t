use strict; use warnings;

use Test::More;
use_ok('Japster');

check( 'foo=1&bar=2', {foo => 1, bar => 2} );
check( 'foo[]=1', {foo=>[1]} );
check( 'foo[]=1&foo[]=2', {foo=>[1, 2]} );
check( 'foo[xxx]=1&foo[yyy]=2', {foo=>{xxx=>1, yyy => 2}} );
check( 'foo[0][x]=1&foo[1][y]=2', {foo=>[{x=>1}, {y => 2}]} );
check( 'foo[][]=1&foo[][]=2', {foo=>[[1, 2]]} );

# bad things:
check( 'foo[2]=1', {foo=>[undef, undef, 1]} );
check( 'foo[]=1&foo[x]=2', { foo=> {''=>[1], x =>2 } } );
check( 'foo[x]=2&foo[]=1', { foo=> {''=>[1], x =>2 } } );

sub check {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    is_deeply(Japster->query_parameters( {QUERY_STRING => shift} ), shift);
}

done_testing();
