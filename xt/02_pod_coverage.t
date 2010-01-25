use Test::More;
use Test::Pod::Coverage;

my @modules = grep { $_ !~ /^Hailo::(?:Tokenizer|Storage)::/ } all_modules();

plan tests => scalar @modules;

pod_coverage_ok($_) for @modules;
