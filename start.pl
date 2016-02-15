#!/usr/bin/env perl

$|=1;
use utf8;
use strict;
use warnings;
use feature qw/say switch unicode_strings/;

use Coro;
use VK::MP3;
use JSON::XS;
use Coro::LWP;
use File::Slurp;
use LWP::UserAgent;
use Term::ProgressBar;

print 'Read configuration ...';
my $config = undef;
eval { $config = decode_json(read_file('config.json')) };
if ($@) {
	say 'Cannot read config file! Error:';
	die $@;
}
say "\r".'Read configuration ... OK';

unless (defined $config->{user}->{login} or defined $config->{user}->{password}) {
  die "Authorization data is not specified!";
}

my @searches = read_file($config->{path}->{input}); chomp(@searches);

unless (-d $config->{path}->{results}) {
	mkdir($config->{path}->{results});
}

print 'Login ...';
my $vk = VK::MP3->new(login => $config->{user}{login}, password => $config->{user}{password});
say "\r".'Login ... OK';

my $progress_bar = Term::ProgressBar->new(scalar(@searches));
my $current_progress = 0;

my @coros;
for (1..$config->{threads}) {
  push @coros, async {
    while (@searches) {
      my $search = shift(@searches);
      download($search, $vk);
    }
  }
}

$_->join for @coros;

sub download {
  my ($search, $vk) = @_;

  my $result = $vk->search($search);
  return if (@{$result} == 0);

  $result = $result->[0];
  $vk->{ua}->get($result->{link}, ':content_file' => $config->{path}->{results}.'/'.$result->{name}.'.mp3');

  $progress_bar->message('[Downloaded] Search: '.$search.' File: '.$config->{path}->{results}.'/'.$result->{name}.'.mp3');
  $progress_bar->update(++$current_progress);
}
