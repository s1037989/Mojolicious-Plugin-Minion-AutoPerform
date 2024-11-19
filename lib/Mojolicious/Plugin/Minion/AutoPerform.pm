package Mojolicious::Plugin::Minion::AutoPerform;
use Mojo::Base 'Mojolicious::Plugin', -signatures;

use Mojo::IOLoop;

sub register ($self, $app, $conf) {
  Mojo::IOLoop->recurring($conf->{auto_perform} || 3 => sub {
    my $minion = $app->minion;
    my $workers = $minion->workers;
    return if $workers->total;
    my @inactive;
    my $queues = $conf->{queues} || ['default'];
    $minion->jobs({states => ['inactive'], queues => $queues})->each(sub {push @inactive, $_->{id}});
    my $inactive = $#inactive + 1;
    return unless $inactive;
    if ($conf->{require_worker} // 1) {
      $app->log->warn(sprintf 'No registered workers, NOT performing %d jobs (%s) in app', $inactive, join ', ', @inactive);
    }
    else {
      my $queued = $minion->jobs({queues => $queues})->total;
      $minion->perform_jobs({queues => $queues});
      my $performed = $queued - $minion->jobs({queues => $queues})->total;
      $app->log->warn(sprintf 'No registered workers but performed %d jobs in app', $performed) if $performed && $app->mode eq 'production';
    }
  });

  return $self;
}

1;
