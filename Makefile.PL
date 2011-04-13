use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'CPAN::Changes::Web',
    AUTHOR       => q{YOUR NAME <youremail@example.com>},
    VERSION_FROM => 'lib/CPAN/Changes/Web.pm',
    ABSTRACT     => 'YOUR APPLICATION ABSTRACT',
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002
        ? ( 'LICENSE' => 'perl' )
        : () ),
    PL_FILES  => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'YAML'       => 0,
        'Dancer'     => 1.3020, # required for ':script'
        # App requirements
        'Dancer::Plugin::DBIC'         => 0,
        'DBIx::Class'                  => 0,
        'Template'                     => 0,
        'Template::Plugin::Pagination' => 0,
        'DBIx::Class::TimeStamp'       => 0,
        'XML::Atom::SimpleFeed'        => 0,
        'HTML::Entities'               => 0,
        'CPAN::Changes'                => '0.16',
        'CPAN::DistnameInfo'           => 0,
        'CPAN::Mini::Visit'            => '0.13',
        'Parse::CPAN::Authors'         => 0,
        'Try::Tiny'                    => 0,
        'Text::Diff'                   => 0,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'CPAN-Changes-Web-*' },
);
