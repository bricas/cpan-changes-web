package CPAN::Changes::Web::Schema::Result::Release;

use strict;
use warnings;

use base qw( DBIx::Class );

__PACKAGE__->load_components( qw( TimeStamp Core ) );
__PACKAGE__->table( 'release' );
__PACKAGE__->add_columns(
    id => {
        data_type         => 'bigint',
        is_auto_increment => 1,
        is_nullable       => 0,
    },
    distribution => {
        data_type   => 'varchar',
        size        => 512,
        is_nullable => 0,
    },
    author => {
        data_type   => 'varchar',
        size        => 512,
        is_nullable => 0,
    },
    version => {
        data_type   => 'varchar',
        size        => 128,
        is_nullable => 0,
    },
    dist_timestamp => {
        data_type   => 'datetime',
        is_nullable => 0,
    },
    changes_fulltext => {
        data_type   => 'text',
        is_nullable => 1,
    },
    changes_release_date => {
        data_type   => 'varchar',
        size        => 64,
        is_nullable => 1,
    },
    changes_for_release => {
        data_type   => 'text',
        is_nullable => 1,
    },
    failure => {
        data_type   => 'text',
        is_nullable => 1,
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
# "COLLATE NOCASE" is an SQLite-ism
__PACKAGE__->resultset_attributes( { order_by => [ 'distribution COLLATE NOCASE' ] } );
__PACKAGE__->add_unique_constraint(
    release_key => [ qw( distribution author version ) ], );

__PACKAGE__->has_many( scan_release_joins =>
        'CPAN::Changes::Web::Schema::Result::ScanReleaseJoin' =>
        'release_id' );
__PACKAGE__->many_to_many( scans => 'scan_release_joins' => 'scan' );

1;
