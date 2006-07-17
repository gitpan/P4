/*
Copyright (c) 1997-2004, Perforce Software, Inc.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1.  Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

2.  Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL PERFORCE SOFTWARE, INC. BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

/*
 * Include math.h here because it's included by some Perl headers and on
 * Win32 it must be included with C++ linkage. Including it here prevents it
 * from being reincluded later when we include the Perl headers with C linkage.
 */
#ifdef OS_NT
#  include <math.h>
#endif

/* When including Perl headers, make sure the linkage is C, not C++ */
extern "C" 
{
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
}

// Undef conflicting macros defined by Perl
#undef Error
#undef Null
#undef Stat
#undef Copy

#include "clientapi.h"
#include "strtable.h"
#include "debug.h"
#include "p4perldebug.h"
#include "perlclientapi.h"

/*
 * The architecture of this extension is relatively complex. The main Perl
 * class is P4 which is a blessed scalar containing pointers to our C++ 
 * objects which hold all our real data. We try to expose as little as
 * possible of the internals to Perl.
 *
 * As the Perforce API is callback based, we have some tap-dancing to do
 * in order to shim it into Perl space. There are two main C++ classes:
 *
 * 1  PerlClientUser is our subclass of the Perforce ClientUser class. This 
 *    class handles all the user-interface functions needed in the API - i.e.
 *    getting input, writing output/errors etc.
 *
 * 2. PerlClientApi is our interface to the Perforce ClientApi class. It
 *    provides a type-bridge between Perl and C++ and makes sure
 *    that the results it returns are ready for use in Perl space.
 *
 * This module provides the glue between Perl space and C++ space by
 * providing Perl methods that call the C++ methods and return the appropriate
 * results.
 */

#define CLIENT_PTR_NAME 	"_p4client_ptr"

static PerlClientApi *
ExtractClient( SV *var )
{
    if (!(sv_isobject((SV*)var) && sv_derived_from((SV*)var,"P4")))
    {
	warn("Not a P4 object!" );
	return 0;
    }

    HV *	h = (HV *)SvRV( var );
    SV **	c = hv_fetch( h, CLIENT_PTR_NAME, strlen( CLIENT_PTR_NAME ),0);

    if( !c )
    {
	warn( "No '" CLIENT_PTR_NAME "' member found in P4 object!" );
	return 0;
    }

    return (PerlClientApi *) SvIV( *c );
}



MODULE = P4	PACKAGE = P4
VERSIONCHECK: DISABLE

SV *
new( CLASS )
	char *CLASS;

	INIT:
	    SV *		iv;
	    HV *		myself;
	    HV *		stash;
	    PerlClientApi *	c;

	CODE:
	    /*
	     * Create a PerlClientApi object and stash a pointer to it
	     * in an HV.
	     */
	    c = new PerlClientApi();
	    iv = newSViv( (I32)c );

	    myself = newHV();
	    hv_store( myself, CLIENT_PTR_NAME, strlen( CLIENT_PTR_NAME ), iv, 0 );

	    /* Return a blessed reference to the HV */
	    RETVAL = newRV_noinc( (SV *)myself );
	    stash = gv_stashpv( CLASS, TRUE );
	    sv_bless( (SV *)RETVAL, stash );

	OUTPUT:
	    RETVAL

void
DESTROY( THIS )
	SV	*THIS

	INIT:
	    PerlClientApi	*c;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    delete c;

SV *
Dropped( THIS )
	SV	*THIS
	INIT:
	    PerlClientApi	*c;
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->Dropped();
	OUTPUT:
	    RETVAL

void
Disconnect( THIS )
	SV 	*THIS

	INIT:
	    PerlClientApi *	c;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->Disconnect();

SV *
GetClient( THIS )
	SV 	*THIS

	INIT:
	    PerlClientApi*	c;
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->GetClient();
	OUTPUT:
	    RETVAL

SV *
GetCwd( THIS )
	SV 	*THIS

	INIT:
	    PerlClientApi *	c;
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->GetCwd();
	OUTPUT:
	    RETVAL

SV *
GetHost( THIS )
	SV 	*THIS

	INIT:
	    PerlClientApi *	c;
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->GetHost();
	OUTPUT:
	    RETVAL

SV *
GetLanguage( THIS )
	SV 	*THIS

	INIT:
	    PerlClientApi *	c;
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->GetLanguage();
	OUTPUT:
	    RETVAL


SV *
GetPassword( THIS )
	SV 	*THIS

	INIT:
	    PerlClientApi *	c;
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->GetPassword();
	OUTPUT:
	    RETVAL

SV *
GetPort( THIS )
	SV 	*THIS

	INIT:
	    PerlClientApi *	c;
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->GetPort();
	OUTPUT:
	    RETVAL

SV *
GetCharset( THIS )
	SV 	*THIS

	INIT:
	    PerlClientApi *	c;
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->GetCharset();
	OUTPUT:
	    RETVAL

SV *
GetUser( THIS )
	SV 	*THIS

	INIT:
	    PerlClientApi *	c;
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->GetUser();
	OUTPUT:
	    RETVAL


SV *
Connect( THIS )
	SV 	*THIS

	INIT:
	    PerlClientApi *	c;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->Connect();
	OUTPUT:
	    RETVAL

SV *
_Run( THIS, cmd, ... )
	SV *THIS
	SV *cmd
	INIT:
	    PerlClientApi *	c;

	    I32			va_start = 2;
	    I32			debug = 0;
	    I32			argc;
	    I32			stindex;
	    I32			argindex;
	    STRLEN		len = 0;
	    char *		currarg;
	    char **		cmdargs = NULL;
	    SV *		sv;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    debug = c->GetDebugLevel();

	    /*
	     * First check that the client has been initialised. Otherwise
	     * the result tends to be a SEGV
	     */
	    if ( !c->IsConnected() )
	    {
		warn("P4::Run() - Not connected. Call P4::Connect() first" );
		XSRETURN_UNDEF;
	    }

	    if ( P4PERL_DEBUG_CMDS )
		printf( "[P4::Run] Running a \"p4 %s\" with %d args\n", 
			SvPV_nolen( cmd ),
			items - va_start );

	    if ( items > va_start )
	    {
		argc = items - va_start;
		New( 0, cmdargs, argc, char * );
		for ( stindex = va_start, argindex = 0; 
			argc; 
			argc--, stindex++, argindex++ )
		{
		    if ( SvPOK( ST(stindex) ) )
		    {
			currarg = SvPV( ST(stindex), len );
			cmdargs[argindex] =  currarg ;
		    }
		    else if ( SvIOK( ST(stindex) ) )
		    {
			/*
			 * Be friendly and convert numeric args to 
		         * char *'s. Use Perl to reclaim the storage.
		         * automatically by declaring them as mortal SV's
		         */
			char	buf[32];
			STRLEN	len;
			sprintf(buf, "%d", SvIV( ST( stindex ) ) );
			sv = sv_2mortal(newSVpv( buf, 0 ));
			currarg = SvPV( sv, len );
			cmdargs[argindex] = currarg;
		    }
		    else
		    {
			/*
		         * Can't handle other arg types
		         */
			printf( "\tArg[ %d ] unknown type %d\n", argindex, 
				SvTYPE( ST(stindex) ) );
		        warn( "Invalid argument to P4::Run. Aborting command" );
			XSRETURN_UNDEF;
		    }
		}
	    }

	    len = 0;
	    currarg = SvPV( cmd, len );
	    if ( P4PERL_DEBUG_CMDS )
	    {
	        for ( int i = 0; i < items - va_start; i++ )
		    printf("[P4::Run] Arg[%d] = %s\n", i, cmdargs[i] );
	    }
	    RETVAL = c->Run( currarg, items - va_start, cmdargs );
	    if ( cmdargs )Safefree( cmdargs );

	OUTPUT:
	    RETVAL

SV *
DebugLevel( THIS, ... )
	SV * 	THIS

	INIT:
	    PerlClientApi *	c;

	    I32			va_start = 1;
	    int			level = 0;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;

	    if( items > va_start )
	    {
		// Setting the debug level
		if( !SvIOK( ST( va_start ) ) )
		{
		    warn( "DebugLevel must be an integer" );
		    XSRETURN_UNDEF;
		}
		level = SvIV( ST( va_start ) );
		c->SetDebugLevel( level );
	    }
	    RETVAL = newSViv( c->GetDebugLevel() );

	OUTPUT:
	    RETVAL
	    
void
Errors( THIS )
	SV * 	THIS

	INIT:
	    PerlClientApi *	c;
	    AV *		a;
	    SV **		s;
	    int			i;

	PPCODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    a = c->GetErrors();
	    for( i = 0; i <= av_len( a ); i++ )
	    {
		s = av_fetch( a, i, 0); 
		if( !s ) continue;
		XPUSHs( *s );
	    }

I32
ErrorCount( THIS )
	SV * 	THIS

	INIT:
	    PerlClientApi *	c;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->GetErrorCount();
	OUTPUT:
	    RETVAL
	
SV *
FormatSpec( THIS, type, hash )
	SV *	THIS
	SV *	type
	SV *	hash

	INIT:
	    PerlClientApi *	c;
	    HV *		h;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;

	    if( SvROK( hash ) )
		hash = SvRV( hash );

	    if( SvTYPE( hash ) == SVt_PVHV )
	    {
		h = (HV*) hash;
	    }
	    else
	    {
		printf( "Type is: %d\n", SvTYPE( hash ) );
		warn( "Argument to FormatSpec must be hashref" );
		XSRETURN_UNDEF;
	    }

	    RETVAL = c->FormatSpec( SvPV( type, PL_na ), h );
	OUTPUT:
	    RETVAL

I32
IsParseForms( THIS )
	SV *	THIS

	INIT:
	    PerlClientApi	*c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->IsParseForms();
	OUTPUT:
	    RETVAL

I32
IsTagged( THIS )
	SV *	THIS

	INIT:
	    PerlClientApi	*c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = c->IsTagged();
	OUTPUT:
	    RETVAL

SV *
MergeErrors( THIS, ... )
	SV *	THIS
	INIT:
	    PerlClientApi *	c;

	    I32			va_start = 1;
	    int			merge = -1;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;

	    if( items > va_start )
	    {
		// Setting the merge flag
		if( !SvIOK( ST( va_start ) ) )
		{
		    warn( "Argument to MergeErrors() must be an integer" );
		    XSRETURN_UNDEF;
		}
		merge = SvIV( ST( va_start ) );
	    }
	    RETVAL = c->MergeErrors( merge );

	OUTPUT:
	    RETVAL
	    
void
ParseForms( THIS )
	SV *	THIS

	INIT:
	    PerlClientApi	*c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->ParseForms();


SV *
ParseSpec( THIS, type, buf )
	SV *	THIS
	SV *	type
	SV *	buf

	INIT:
	    PerlClientApi	*c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;

	    RETVAL = c->ParseSpec( SvPV( type, PL_na ), SvPV( buf, PL_na ) );
	OUTPUT:
	    RETVAL


void
SetApiLevel( THIS,  level )
	SV *	THIS
	SV *	level

	INIT:
	    PerlClientApi	*c;
	
	CODE:
	    if( !SvIOK( level ) )
	    {
		warn( "API level must be an integer" );
		XSRETURN_UNDEF;
	    }

	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;

	    c->SetApiLevel( SvIV( level ) );


void
SetCharset( THIS,  charset )
	SV *	THIS
	char *	charset

	INIT:
	    PerlClientApi	*c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetCharset( charset );


void
SetClient( THIS, clientName )
	SV	*THIS
	char 	*clientName

	INIT:
	    PerlClientApi *	c;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetClient( clientName );


void
_SetCwd( THIS, cwd )
	SV *	THIS
	char *	cwd

	INIT:
	    PerlClientApi *	c;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetCwd( cwd );


void
SetHost( THIS, hostname )
	SV *	THIS
	char *	hostname

	INIT:
	    PerlClientApi *	c;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetHost( hostname );

void
SetInput( THIS, value )
	SV *	THIS
	SV *	value

	INIT:
	    PerlClientApi *	c;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetInput( value );

void
SetMaxResults( THIS, value )
	SV *	THIS
	int 	value
	INIT:
	    PerlClientApi *	c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetMaxResults( value );


void
SetMaxScanRows( THIS, value )
	SV *	THIS
	int 	value
	INIT:
	    PerlClientApi *	c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetMaxScanRows( value );


void
SetPassword( THIS, password )
	SV *	THIS
	char *	password
	INIT:
	    PerlClientApi *	c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetPassword( password );


void
SetPort( THIS,  address )
	SV *	THIS
	char *	address

	INIT:
	    PerlClientApi	*c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetPort( address );

void
SetProg( THIS,  name )
	SV *	THIS
	char *	name

	INIT:
	    PerlClientApi	*c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetProg( name );

void
SetProtocol( THIS, protocol, value )
	SV *	THIS
	char *	protocol
	char *	value

	INIT:
	    PerlClientApi	*c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetProtocol( protocol, value );

void
SetUser( THIS, username )
	SV *	THIS
	char *	username

	INIT:
	    PerlClientApi *	c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->SetUser( username );

void
Tagged( THIS )
	SV *	THIS

	INIT:
	    PerlClientApi	*c;
	
	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    c->Tagged();


SV *
WarningCount( THIS )
	SV *	THIS

    	INIT:
	    PerlClientApi *	c;

	CODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    RETVAL = newSViv( c->GetWarningCount() );

	OUTPUT:
	    RETVAL

void
Warnings( THIS )
	SV * 	THIS

	INIT:
	    PerlClientApi *	c;
	    AV *		a;
	    SV **		s;
	    int			i;

	PPCODE:
	    c = ExtractClient( THIS );
	    if( !c ) XSRETURN_UNDEF;
	    a = c->GetWarnings();
	    for( i = 0; i <= av_len( a ); i++ )
	    {
		s = av_fetch( a, i, 0); 
		if( !s ) continue;
		XPUSHs( *s );
	    }
