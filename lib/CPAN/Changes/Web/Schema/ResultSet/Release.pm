package CPAN::Changes::Web::Schema::ResultSet::Release;

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet';

sub passes {
    return shift->search( { failure => undef } );
}

sub failures {
    return shift->search( { failure => { -not => undef } } );
}

1;
