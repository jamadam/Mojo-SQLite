package Mojo::SQLite::Database;
use Mojo::Base -base;

use Carp 'croak';
use DBD::SQLite;
use Mojo::SQLite::Results;
use Mojo::SQLite::Transaction;
use List::Util 'any';
use Scalar::Util 'weaken';

our $VERSION = '0.001';

has [qw(dbh sqlite)];

sub DESTROY {
  my $self = shift;

  # Supported on Perl 5.14+
  return if defined ${^GLOBAL_PHASE} && ${^GLOBAL_PHASE} eq 'DESTRUCT';

  return unless (my $sql = $self->sqlite) && (my $dbh = $self->dbh);
  $sql->_enqueue($dbh);
}

sub begin {
  my $self = shift;
  if (@_) {
    my $behavior = shift;
    croak qq{Invalid transaction behavior $behavior}
      unless any { lc $behavior eq $_ } qw(deferred immediate exclusive);
    $self->dbh->do("begin $behavior transaction");
  } else {
    $self->dbh->begin_work;
  }
  my $tx = Mojo::SQLite::Transaction->new(db => $self);
  weaken $tx->{db};
  return $tx;
}

sub disconnect {
  my $self = shift;
  $self->dbh->disconnect;
}

sub ping { shift->dbh->ping }

sub query {
  my ($self, $query) = (shift, shift);

  my $sth = $self->dbh->prepare_cached($query, undef, 3);
  $sth->execute(@_);

  return Mojo::SQLite::Results->new(sth => $sth);
}

1;

=head1 NAME

Mojo::SQLite::Database - Database

=head1 SYNOPSIS

  use Mojo::SQLite::Database;

  my $db = Mojo::SQLite::Database->new(sqlite => $sql, dbh => $dbh);
  $db->query('select * from foo')
    ->hashes->map(sub { $_->{bar} })->join("\n")->say;

=head1 DESCRIPTION

L<Mojo::SQLite::Database> is a container for L<DBD::SQLite> database handles
used by L<Mojo::SQLite>.

=head1 ATTRIBUTES

L<Mojo::SQLite::Database> implements the following attributes.

=head2 dbh

  my $dbh = $db->dbh;
  $db     = $db->dbh(DBI->new);

L<DBD::SQLite> database handle used for all queries.

=head2 sqlite

  my $pg = $db->pg;
  $db    = $db->pg(Mojo::SQLite->new);

L<Mojo::SQLite> object this database belongs to.

=head1 METHODS

L<Mojo::SQLite::Database> inherits all methods from L<Mojo::Base> and
implements the following new ones.

=head2 begin

  my $tx = $db->begin;
  my $tx = $db->begin('exclusive');

Begin transaction and return L<Mojo::SQLite::Transaction> object, which will
automatically roll back the transaction unless
L<Mojo::SQLite::Transaction/"commit"> has been called before it is destroyed.

  # Insert rows in a transaction
  eval {
    my $tx = $db->begin;
    $db->query('insert into frameworks values (?)', 'Catalyst');
    $db->query('insert into frameworks values (?)', 'Mojolicious');
    $tx->commit;
  };
  say $@ if $@;

A transaction locking behavior of C<deferred>, C<immediate>, or C<exclusive>
may optionally be passed; the default in L<DBD::SQLite> is currently
C<immediate>. See L<DBD::SQLite/"Transaction and Database Locking"> for more
details.

=head2 disconnect

  $db->disconnect;

Disconnect L</"dbh"> and prevent it from getting cached again.

=head2 ping

  my $bool = $db->ping;

Check database connection.

=head2 query

  my $results = $db->query('select * from foo');
  my $results = $db->query('insert into foo values (?, ?, ?)', @values);

Execute a blocking statement and return a L<Mojo::SQLite::Results> object with
the results. The L<DBD::SQLite> statement handle will be automatically reused
when it is not active anymore, to increase the performance of future queries.

=head1 BUGS

Report any issues on the public bugtracker.

=head1 AUTHOR

Dan Book, C<dbook@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2015, Dan Book.

This library is free software; you may redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 SEE ALSO

L<Mojo::SQLite>