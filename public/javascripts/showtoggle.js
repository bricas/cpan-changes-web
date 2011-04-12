$( document ).ready( function() {

    // All
    $( '#showall' ).click( function() {
        $( '#showall' ).css( 'font-weight', 'bold' );
        $( '#showpass,#showfail' ).css( 'font-weight', 'normal' );
        $( '#releases li' ).show();
        return false;
    } );

    // Pass
    $( '#showpass' ).click( function() {
        $( '#showpass' ).css( 'font-weight', 'bold' );
        $( '#showall,#showfail' ).css( 'font-weight', 'normal' );
        $( '#releases li.pass' ).show();
        $( '#releases li.fail' ).hide();
        return false;
    } );

    // Fail
    $( '#showfail' ).click( function() {
        $( '#showfail' ).css( 'font-weight', 'bold' );
        $( '#showall,#showpass' ).css( 'font-weight', 'normal' );
        $( '#releases li.fail' ).show();
        $( '#releases li.pass' ).hide();
        return false;
    } );

} );
