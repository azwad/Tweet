package PostMedia;
use base qw( Tweet );
use feature 'say';

sub post_media {
	
    my($self, $text, $url, $media) = @_;
		my $post_tweet = $self->compose_tweet($text,$url);
		$self->initialize_twitter;
		
		eval { $self->{twitter}->update_with_media($post_tweet, $media)};

		if ($@) {
			my $error =  $@;
			warn "uppdate failed because: $error\n" ;
			$self->is_success(0);
			$self->{is_error} = $error;
			return $self;
		}else{
			say 'post succeeded';
			$self->is_success(1);
			return  $self;
		}
}

1;
