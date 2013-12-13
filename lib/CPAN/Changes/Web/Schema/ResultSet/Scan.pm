package CPAN::Changes::Web::Schema::ResultSet::Scan;

use strict;
use warnings;

use parent 'DBIx::Class::ResultSet';

sub latest {
    return shift->search( { is_running => 0 }, { order_by => 'run_date desc' } )->first;
}

1;
