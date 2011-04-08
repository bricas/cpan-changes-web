package CPAN::Changes::Web::Schema::Result::Author;

use strict;
use warnings;

use base qw( DBIx::Class );

__PACKAGE__->load_components( qw( TimeStamp Core ) );
__PACKAGE__->table( 'author' );
__PACKAGE__->add_columns(
    id => {
        data_type         => 'varchar',
        is_auto_increment => 50,
        is_nullable       => 0,
    },
    name => {
        data_type   => 'varchar',
        size        => 512,
        is_nullable => 0,
    },
    email => {
        data_type   => 'varchar',
        size        => 512,
        is_nullable => 0,
    },
    ctime => {
        data_type     => 'datetime',
        default_value => \'CURRENT_TIMESTAMP',
        set_on_create => 1,
    },
    mtime => {
        data_type     => 'datetime',
        default_value => \'CURRENT_TIMESTAMP',
        set_on_create => 1,
        set_on_update => 1,
    },
);
__PACKAGE__->set_primary_key( 'id' );
__PACKAGE__->resultset_attributes( { order_by => [ 'id' ] } );

__PACKAGE__->has_many(
    releases => 'CPAN::Changes::Web::Schema::Result::Release' => 'author' );

1;
