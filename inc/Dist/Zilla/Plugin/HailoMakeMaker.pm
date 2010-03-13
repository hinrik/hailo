package inc::Dist::Zilla::Plugin::HailoMakeMaker;
use Moose;

extends 'Dist::Zilla::Plugin::OverridableMakeMaker';

override _build__makemaker_template => sub {
    my ($self) = @_;
    my $template = super();

    $template .= <<'TEMPLATE';
package MY;

sub test {
    my $inherited = shift->SUPER::test(@_);

    # Run tests with Moose and Mouse
    $inherited =~ s/^test_dynamic :: pure_all\n\t(.*?)\n/test_dynamic :: pure_all\n\tANY_MOOSE=Mouse $1\n\tANY_MOOSE=Moose $1\n/m;

    return $inherited;
}
TEMPLATE

    return $template;
};

__PACKAGE__->meta->make_immutable;
