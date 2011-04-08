package CPAN::Changes::Web::Schema::ResultSet::Release;

use strict;
use warnings;

use DateTime;

use parent 'DBIx::Class::ResultSet';

sub passes {
    return shift->search( { failure => undef } );
}

sub failures {
    return shift->search( { failure => { -not => undef } } );
}

sub recent {

    # Probably a better way to do this...
    return shift->search(
        {   dist_timestamp => {
                '>=',
                \q((SELECT strftime('%Y-%m-%d', MAX( dist_timestamp )) FROM release))
            }
        },
        { order_by => 'dist_timestamp DESC' }
    );
}

sub authors {
    return
        shift->search_related_rs( 'author_info', {},
        { order_by => 'author_info.id', distinct => 1 } );
}

1;
