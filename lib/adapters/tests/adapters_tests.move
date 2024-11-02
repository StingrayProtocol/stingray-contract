#[test_only]
module adapters::adapters_tests;
// uncomment this line to import the module
// use adapters::adapters;

const ENotImplemented: u64 = 0;

#[test]
fun test_adapters() {
    // pass
}

#[test, expected_failure(abort_code = ::adapters::adapters_tests::ENotImplemented)]
fun test_adapters_fail() {
    abort ENotImplemented
}
