package Bot::Pluggable::Blogger;
$VERSION = 0.01;
use strict; 
use warnings;
use base qw(Bot::Pluggable::Common);


=head1 NAME

Bot::Pluggable::Blogger - ...

=head1 SYNOPSIS

my $blogger = new Bot::Pluggable::Blogger(
   url=>'http://bender.prather.org/',
   proxy=>'http://www.prather.org/cgi-bin/mt/mt-xmlrpc.cgi',
   user=>'IRC_BLOGGER',
   pass=>'password',
   blog_id=>'2',
   DEBUG=>1,
);

my $bot = Bot::Pluggable->new(
    Modules => [],
    Objects => [$blogger],
    Nick => 'Blogger',
    Server => 'london.rhizomatic.net',
    Port => 6667,
);

$poe_kernel->run();
exit(0);

=head1 DESCRIPTION
         A Wrapper around Net::Blogger to allow posting from IRC to a Blogger
			 API (for example to a Moveable Type based Blog).
			 
=cut

use POE;
use HTML::Entities;
use Net::Blogger;

sub getBlogger {
    my ($self) = @_;
    my $mt = Net::Blogger->new(engine=>"movabletype");
    $mt->Proxy("$self->{proxy}");
    $mt->Username("$self->{user}");
    $mt->Password("$self->{pass}");
    $mt->BlogId($self->{blog_id});
    return $mt;		
}

sub post {
    my ($self, $message, $nick) = @_;
    print STDERR "posting $message to $self->{url} because of $nick\n" if $self->{DEBUG}; 
    my $mt = $self->getBlogger;
		 my $title = (join ' ', (split /\s+/, $message)[0..2]).'...';
    $message = encode_entities($message, '<>&');
    my $postID = $mt->metaWeblog()->newPost(title=>encode_entities($title), description=>"$nick says:\n\n $message", publish=>1);      
    return "POSTED: $postID";
}

sub update_post {
		my ($self, $postID, $message, $nick) = @_;
    my $mt = $self->getBlogger();
		my $post = $mt->metaWeblog()->getPost(postid=>$postID) or warn $mt->LastError();
		return "Post not found" unless $post;
   ($message, $nick) = encode_entities($message, '<>&"'), encode_entities($nick));
		my $ok = $mt->editPost(postid=>$postID, postbody=>\"$post->{description}\n$nick:\n\n $message", publish=>1);
		return "UPDATED: $postID" if $ok;
		return $mt->LastError();
}

sub title_post {
    my ($self, $postID, $title) = @_;
    my $mt = $self->getBlogger();
    my $post = $mt->metaWeblog()->getPost(postid=>$postID) or warn $mt->LastError();
    return "Post not found" unless $post;
    my $ok = $mt->metaWeblog()->editPost(postid=>$postID, title=>encode_entities($title), description=>$post->{description}, publish=>1);
    return "TITLED: $postID" if $ok;
    return $mt->LastError();
}

sub told {
    my ($self, $nick, $channel, $message) = @_;
    my $sender = $channel || $nick;
    for ($message) {
        /^post[\:\,\;\.]?\s+(.+)$/i && do { $self->tell($sender, $self->post($1, $nick)) };
        /^update\s+(\d+)[\:\,\;\.]?\s+(.+)$/i && do { $self->tell($sender, $self->update_post($1, $2, $nick)) };
        /^title\s+(\d+)[\:\,\;\.]?\s+(.+)$/i && do { $self->tell($sender, $self->title_post($1, $2)) };
        /^url\??$/ && do { $self->tell($sender, "Try: $self->{url}") };
    }
}

#
# EVENTS
#

sub irc_public {
    my ($self, $bot, $nickstring, $channels, $message) = @_[OBJECT, SENDER, ARG0, ARG1, ARG2];  
    my $nick = $self->nick($nickstring);
    my $me = $bot->{Nick};
    $self->told($nick, $channels->[0], $1) if ($message =~ m/^\s*$me[\:\,\;\.]?\s*(.*)$/i);
		 return 0;
}

sub irc_msg {
    my ($self, $bot, $nickstring, $recipients, $message) = @_[OBJECT, SENDER, ARG0, ARG1, ARG2];
    my $nick = $self->nick($nickstring);
    $self->told($nick, undef, $message);
		return 0;
}

=head1 LIMITATIONS

=head1 COPYRIGHT

    Copyright 2003, Chris Prather, All Rights Reserved

=head1 LICENSE

You may use this module under the terms of the BSD, Artistic, oir GPL licenses,
any version.

=head1 AUTHOR

Chris Prather <chris@prather.org>

=cut

1;
