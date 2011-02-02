use Test::More;

eval "use Test::Pod::Coverage 1.00";
plan skip_all => "Test::Pod::Coverage required for testing 99_pod.t" if $@;
all_pod_coverage_ok();
