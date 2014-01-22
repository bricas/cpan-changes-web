$('document').ready( function() {
    $( '#nav-search-button a' ).click( function() {
        var search = $( '.navbar form[role="search"]' );
        var hidden = $( '<input type="hidden">' );
        hidden.attr( 'name', $( this ).data( 'name' ) ); 
        hidden.attr( 'value', $( this ).data( 'value' ) ); 
        search.prepend( hidden );
        search.submit();
        return false;
    } );
} );
