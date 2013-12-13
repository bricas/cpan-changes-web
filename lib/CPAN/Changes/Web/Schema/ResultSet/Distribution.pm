package CPAN::Changes::Web::Schema::ResultSet::Distribution;

use strict;
use warnings;

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
                # SQLite-ism
                \q((SELECT strftime('%Y-%m-%d', MAX( dist_timestamp )) FROM distribution_release))
                # \q((SELECT DATE_FORMAT(MAX(dist_timestamp), '%Y-%m-%d') FROM distribution_release))
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
