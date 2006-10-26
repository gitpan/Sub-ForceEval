use ExtUtils::MakeMaker;

WriteMakefile
(

    NAME            => 'Sub::ForceEval',
    VERSION         => '1.21',
    ABSTRACT_FROM   => 'lib/Sub/ForceEval.pm',
    PREREQ_PM =>
    {
        strict              => 0,
        Carp                => 0,
        Symbol              => 0,
        version             => 0,
        Attribute::Handlers => 0.78
    },

);
