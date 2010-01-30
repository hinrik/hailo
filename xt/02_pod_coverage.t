use 5.10.0;
use Test::More;
use Test::Pod::Coverage;

my @modules = grep { $_ !~ /^Hailo::(?:Tokenizer|Storage|Engine)::/ } all_modules();

plan tests => scalar @modules;

pod_coverage_ok($_) for @modules;
