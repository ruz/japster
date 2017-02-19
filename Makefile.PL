use inc::Module::Install;

all_from('lib/Japster.pm');
readme_from_pod('lib/Japster.pm');

requires
    'Promises' => 0,
    'Scalar::Util' => 0,
    'JSON' => 0,
    'Async::ContextSwitcher' => 0,
    'Carp' => 0,
    'URI::Escape' => 0,
    'Encode' => 0,
;

test_requires
    'Test::More' => 0.88,
;
WriteAll();
