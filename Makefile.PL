use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Bot::Pluggable::Blogger',
    VERSION_FROM  => 'lib/Bot/Pluggable/Blogger.pm',
    EXE_FILES     => [],
    PREREQ_PM => { 
	  	Bot::Pluggable => 0.03,
			Net::Blogger => 0.85,
			HTML::Entities => 1.24,
		},
);


sub MY::libscan {
    package MY;
    my $self = shift;
    my ( $path ) = @_;
    return '' if /\.sw[a-z]$/;
    return '' unless length $self->SUPER::libscan( $path );
    return $path;
}
