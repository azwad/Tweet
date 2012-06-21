package Tweet;
use strict;
use utf8;
use feature 'say';
#use Encode qw( encode_utf8 decode_utf8 );
use Net::Twitter;
use Time::HiRes qw(sleep);
use LWP::UserAgent;
use HTTP::Request;
use HTML::Scrubber;
use WebService::Bitly;
use Config::Pit;
use Moose;

has 'init' => (
	isa => 'HashRef',
	is => 'rw',
	default => sub { {'pit_twitter' => '',
										'pit_bitly'  => '',
									}},
);

has 'config_twitter' => (
	isa => 'HashRef',
	is => 'rw',
);

has 'config_bitly' => (
	isa => 'HashRef',
	is => 'rw',
);

has 'is_success' => (
	isa => 'Bool',
	is => 'rw',
);


__PACKAGE__->meta->make_immutable;
no Moose;


sub initialize_twitter {
		my $self = shift;
		my $pit_twitter = $self->init->{pit_twitter};

		$self->{config_twitter} = Config::Pit::pit_get($pit_twitter, require => {
			'consumer_key' => 'twitter consumer key',
			'consumer_secret' => 'twitter consumer secret',
			'access_token'		=> 'twitter access token',
			'access_token_secret' => 'twitter access token seceret',
			}
		);

		my %opt = (
			traits   => ['API::REST', 'OAuth'],
		);
		$opt{access_token} = $self->config_twitter->{access_token};
		$opt{access_token_secret} = $self->config_twitter->{access_token_secret};
 

		for my $key (qw/apihost apiurl apirealm consumer_key consumer_secret/) {
			$opt{$key} = $self->config_twitter->{$key} if $self->config_twitter->{$key};
		}
		my $nettwitter = Net::Twitter->new(%opt);

		$self->{twitter} = $nettwitter;
		return $self;
}

sub url_shorten {
		my ($self, $url) = @_;

		my $pit_bitly = $self->init->{pit_bitly};
		$self->{config_bitly} = Config::Pit::pit_get($pit_bitly, require => {
				'user_name' => 'bitly user name',
				'user_api_key' => 'bitly user api key',
			}
		);

		my $bitly = WebService::Bitly->new(
			'user_name' => $self->config_bitly->{user_name},
			'user_api_key' =>  $self->config_bitly->{user_api_key},
		);

		my $res = $bitly->shorten($url);
		my $link;
		if ($res->is_error) {
			my $tinyurl = "http://tinyurl.com/api-create.php?url=$url";
			my $ua = LWP::UserAgent->new();
			my $req = HTTP::Request->new('GET', $tinyurl);
			my $res_tinyurl = $ua->request($req);
			$link = $res_tinyurl->content;
		}else{
			$link = $res->short_url;
		}
		return $link;
}


sub compose_tweet {
    my($self, $text, $url) = @_;

		my ($link, $length_link);
		if ($url){
			$link = $self->url_shorten($url);
			$length_link = length($link);
		}else{
			$link = undef;
			$length_link = 0;
		};

		my $scrubber_text = HTML::Scrubber->new();
		my $post_text = $scrubber_text->scrub($text);

		my $length_post_text = length($post_text);
#		say $length_post_text;

		my $maxlength = 138 - $length_link;

		if ($length_post_text > $maxlength) {
			$post_text = substr($post_text, 0, $maxlength -3 );
		}

		my $post_tweet = $post_text.".. ".$link;
		
		return $post_tweet;
}

sub post_tweet {
	
    my($self, $text, $url) = @_;
		my $post_tweet = $self->compose_tweet($text,$url);
		$self->initialize_twitter;
		
		eval { $self->{twitter}->update($post_tweet)};

		if ($@) {
		warn "uppdate failed because: $@\n" ;
		$self->is_success(0);
		return $self;
		}else{
		say 'post succeeded';
		$self->is_success(1);
		return  $self;
		}
}

1;
