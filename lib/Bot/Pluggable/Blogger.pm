package Bot::Pluggable::Blogger;
$VERSION = 0.02;
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

use HTML::Entities;
use Net::Blogger;
use POE;

sub BEGIN { print STDERR __PACKAGE__ . " Loaded\n" }

sub blog {
    my ($self) = @_;
    my $mt = Net::Blogger->new(engine=>$self->{type});
    $mt->Proxy($self->{proxy});
    $mt->Username($self->{user});
    $mt->Password($self->{pass});
    $mt->AppKey($self->{app_key}) if defined $self->{app_key};
    $mt->BlogId($self->{blog_id} || $mt->GetBlogId(blogname=>$self->{blog_name})) || die "Could Not get Blog";
    print STDERR "Got Blog\n" if $self->{DEBUG}; 
    return $mt;     
}

sub post {
    my ($self, $message, $nick, $sender) = @_;
    print STDERR "posting $message to $self->{url} because of $nick\n" if $self->{DEBUG}; 
    my $mt = $self->blog;  
    my $title = (join ' ', (split /\s+/, $message)[0..2]).'...';
    $message = "$nick says:\n" . encode_entities($message, '<>&');
    my $postID = $mt->metaWeblog()->newPost(title=>encode_entities($title), description=>$message, publish=>1);
    return $self->tell($sender, $mt->LastError())  unless $postID;
    return $self->tell($sender, "POSTED: $postID");
}

sub update_post {
    my ($self, $postID, $message, $nick, $sender) = @_;
    my $mt = $self->blog();
    my $post = $mt->metaWeblog()->getPost(postid=>$postID) or warn $mt->LastError();
    return $self->tell($sender, "Post not found") unless $post;
   ($message, $nick) = (encode_entities($message, '<>&"'), encode_entities($nick));
    my $postbody = "$post->{description}\n\n$nick:\n $message";
    my $ok = $mt->editPost(postid=>$postID, postbody=>\$postbody, publish=>1);
    return $self->tell($sender, "UPDATED: $postID") if $ok;
    return $self->tell($sender, $mt->LastError());
}

sub title_post {
    my ($self, $postID, $title, $sender) = @_;
    my $mt = $self->blog();
    my $post = $mt->metaWeblog()->getPost(postid=>$postID) or warn $mt->LastError();
    return $self->tell($sender, "Post not found") unless $post;
    my $ok = $mt->metaWeblog()->editPost(postid=>$postID, title=>encode_entities($title), description=>$post->{description}, publish=>1);
    return $self->tell($sender, "TITLED: $postID") if $ok;
    return $self->tell($sender, $mt->LastError());
}

sub told {
    my ($self, $nick, $channel, $message) = @_;
    my $sender = $channel || $nick;
    my $SEP_RX = qr{[\:\,\;\.]?};
    for ($message) {
        /^post\s*$SEP_RX\s+(.+)$/ix && return $self->post($1, $nick, $sender);
        /^update\s+(\d+)\s*$SEP_RX\s+(.+)$/i && return $self->update_post($1, $2, $nick, $sender);
        /^(\d+)\s*\.=\s+(.+)$/i && return $self->update_post($1, $2, $nick, $sender);
        /^title\s+(\d+)\s*$SEP_RX\s+(.+)$/i && return $self->title_post($1, $2, $sender);
        /^url\??$/ && return $self->tell($sender, "Try: $self->{url}");
    }
}

#
# EVENTS
#

1;
__END__

=head1 LIMITATIONS

=head1 COPYRIGHT

    Copyright 2003, Chris Prather, All Rights Reserved

=head1 LICENSE

You may use this module under the terms of the BSD, Artistic, oir GPL licenses,
any version.

=head1 AUTHOR

Chris Prather <chris@prather.org>

=cut

