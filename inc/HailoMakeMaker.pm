package inc::HailoMakeMaker;
use Moose;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';

override _build_MakeFile_PL_template => sub {
    my ($self) = @_;
    my $template = super();

    $template .= <<'TEMPLATE';
package MY;

sub test {
    my $inherited = shift->SUPER::test(@_);

    # This trickery fails with Windows's dmake, see
    # http://www.cpantesters.org/cpan/report/07242729-b19f-3f77-b713-d32bba55d77f
    unless ($^O eq 'MSWin32') {
        # Run tests with Moose and Mouse
        $inherited =~ s/^test_dynamic :: pure_all\n\t(.*?)\n/test_dynamic :: pure_all\n\tANY_MOOSE=Mouse $1\n\tANY_MOOSE=Moose $1\n/m;
    }

    return $inherited;
}
TEMPLATE

    return $template;
};

__PACKAGE__->meta->make_immutable;
