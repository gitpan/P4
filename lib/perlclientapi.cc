/*******************************************************************************
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
*******************************************************************************/

/*
 * Include math.h here because it's included by some Perl headers and on
 * Win32 it must be included with C++ linkage. Including it here prevents it
 * from being reincluded later when we include the Perl headers with C linkage.
 */
#ifdef OS_NT
#  include <math.h>
#endif

#include "clientapi.h"
#include "strtable.h"
#include "debug.h"
#include "spec.h"
#include "enviro.h"
#include "i18napi.h"

/* When including Perl headers, make sure the linkage is C, not C++ */
extern "C" 
{
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
}

#ifdef Error
// Defined by older versions of Perl to be Perl_Error
# undef Error
#endif
#include "p4result.h"
#include "p4perldebug.h"
#include "perlclientuser.h"
#include "perlclientapi.h"

PerlClientApi::PerlClientApi()
{
    Enviro	env;

    client	= new ClientApi;
    ui 		= new PerlClientUser();
    initCount 	= 0;
    debug	= 0;
    compatFlags	= 0;
    maxResults	= 0;
    maxScanRows = 0;
    server2	= 0;
    prog	= "P4Perl script";

    if( char *c = env.Get( "P4CHARSET" ) )
	SetCharset( c );
}

PerlClientApi::~PerlClientApi()
{
    Disconnect();
    delete ui;
    delete client;
}

SV *
PerlClientApi::Connect()
{
    Error	e;

    if( initCount )
	return &PL_sv_yes;

    client->Init( &e );
    if( e.Test() )
	ui->HandleError( &e );
    else
	initCount++;

    return initCount ? &PL_sv_yes : &PL_sv_no;
}

SV *
PerlClientApi::Disconnect()
{
    if( !initCount )
	return &PL_sv_yes;

    Error e;
    client->Final( &e );
    initCount--;

    if( e.Test() ) 
	ui->HandleError( &e );
    return e.Test() ? &PL_sv_no : &PL_sv_yes;
}

SV *
PerlClientApi::Dropped()
{
    return newSViv( client->Dropped() );
}

void
PerlClientApi::SetInput( SV *i )
{ 
    ui->SetInput( i );	     
}

void
PerlClientApi::SetApiLevel( int level )
{
    StrBuf	l;
    l << level;
    client->SetProtocol( "api", l.Text() );
}

SV *
PerlClientApi::SetCharset( const char *c )
{
    CharSetApi::CharSet	cs = CharSetApi::Lookup( c );
    if( cs == (CharSetApi::CharSet) -1 )
    {
	warn( "Unknown charset ignored. Check your code or P4CHARSET." );
	return &PL_sv_undef;
    }
    client->SetTrans( cs, cs, cs, cs );
    client->SetCharset( c );
    return &PL_sv_yes;
}


SV *
PerlClientApi::GetCharset()
{
    const StrPtr &c = client->GetCharset();
    return newSVpv( c.Text(), c.Length() );
}

SV *
PerlClientApi::GetClient()
{
    const StrPtr &c = client->GetClient();
    return newSVpv( c.Text(), c.Length() );
}


SV *
PerlClientApi::GetCwd()
{
    const StrPtr &c = client->GetCwd();
    return newSVpv( c.Text(), c.Length() );
}


SV *
PerlClientApi::GetHost()
{
    const StrPtr &c = client->GetHost();
    return newSVpv( c.Text(), c.Length() );
}


SV *
PerlClientApi::GetLanguage()
{
    const StrPtr &c = client->GetLanguage();
    return newSVpv( c.Text(), c.Length() );
}


SV *
PerlClientApi::GetPassword()
{
    const StrPtr &c = client->GetPassword();
    return newSVpv( c.Text(), c.Length() );
}


SV *
PerlClientApi::GetPort()
{
    const StrPtr &c = client->GetPort();
    return newSVpv( c.Text(), c.Length() );
}

SV *
PerlClientApi::GetUser()
{
    const StrPtr &c = client->GetUser();
    return newSVpv( c.Text(), c.Length() );
}

void
PerlClientApi::SetProtocol( const char *p, const char *v )
{
    client->SetProtocol( p, v );
    if( !strcmp( p, "tag" ) )
	mode |= PROTO_TAG;
    else if( !strcmp( p, "specstring" ) )
	mode |= PROTO_SPECSTRING;
}

StrPtr *
PerlClientApi::GetProtocol( const char *v )
{
    return client->GetProtocol( v );
}

void
PerlClientApi::Tagged()
{
    SetProtocol( "tag", "" );
}

void
PerlClientApi::ParseForms()
{
    SetProtocol( "tag", "" );
    SetProtocol( "specstring", "" );
}

int
PerlClientApi::IsTagged() 
{
    return mode & PROTO_TAG;
}

int
PerlClientApi::IsParseForms()
{
    return ( mode & MODE_PARSEFORMS ) == MODE_PARSEFORMS;
}

SV *
PerlClientApi::MergeErrors( int merge )
{
    switch( merge )
    {
    case 0:
	printf( "Disabling merge\n" );
	compatFlags &= ~CPT_MERGED;
	break;

    case 1:
	printf( "Enabling merge\n" );
	compatFlags |= CPT_MERGED;
	break;
    }
    printf( "Merge is %s\n",compatFlags & CPT_MERGED ? "enabled" : "disabled"); 
    return newSViv( compatFlags & CPT_MERGED );
}


SV *
PerlClientApi::GetFirstOutput()
{
    AV * output = ui->GetResults().GetOutput();
    SV **s = av_fetch( output, 0, 0 );
    return s ? *s : 0;
}

AV *
PerlClientApi::GetOutput()
{
    return ui->GetResults().GetOutput();
}

AV *
PerlClientApi::GetWarnings()
{
    return ui->GetResults().GetWarnings();
}

AV *
PerlClientApi::GetErrors()
{
    return ui->GetResults().GetErrors();
}

I32
PerlClientApi::GetOutputCount()
{
    return ui->GetResults().OutputCount();
}

I32
PerlClientApi::GetWarningCount()
{
    return ui->GetResults().WarningCount();
}

I32
PerlClientApi::GetErrorCount()
{
    return ui->GetResults().ErrorCount();
}

void
PerlClientApi::SetDebugLevel( int l )
{
    debug = l;
    ui->SetDebugLevel( l );
    if( P4PERL_DEBUG_RPC )
	p4debug.SetLevel( DT_RPC, 5 );
    else
	p4debug.SetLevel( DT_RPC, 0 );
}

SV *
PerlClientApi::Run( const char *cmd, int argc, char * const *argv )
{
    ui->Reset( compatFlags & CPT_MERGED );

    RunCmd( cmd, ui, argc, argv );

    // 
    // Save the specdef for this command...
    //
    if( ui->LastSpecDef().Length() )
	specDict.SetVar( cmd, ui->LastSpecDef() );

    return newRV( (SV*) GetOutput() );
}

//
// RunCmd is a private function to work around an obscure protocol
// bug in 2000.[12] servers. Running a "p4 -Ztag client -o" messes up the
// protocol so if they're running this command then we disconnect and
// reconnect to refresh it. For efficiency, we only do this if the 
// server2 protocol is either 9 or 10 as other versions aren't affected.
//
void
PerlClientApi::RunCmd( const char *cmd, ClientUser *ui, int argc, char * const *argv )
{
    // If maxresults or maxscanrows is set, enforce them now
    if( maxResults  )	client->SetVar( "maxResults",  maxResults  );
    if( maxScanRows )	client->SetVar( "maxScanRows", maxScanRows );

#if P4API_VERSION >= 513026
    // SetProg first introduced in 2004.2. [ 513026 = ( 2004 << 8 | 2 ) ]
    client->SetProg( prog.Text() );
#endif
    client->SetArgv( argc, argv );
    client->Run( cmd, ui );

    // Have to request server2 protocol *after* a command has been run. I
    // don't know why, but that's the way it is.

    if ( ! server2 )
    {
	StrPtr *pv = client->GetProtocol( "server2" );
	if ( pv )
	    server2 = pv->Atoi();
    }

    if ( IsTagged() && StrRef( cmd ) == "client" && 
	 server2 >= 9    && server2 <= 10  )
    {
	if ( argc && ( StrRef( argv[ 0 ] ) == "-o" ) )
	{
	    if ( P4PERL_DEBUG_FLOW )
		printf( "[P4::Run]: Resetting to avoid obscure 2000.[12] protocol bug\n" );

	    Error e;
	    client->Final( &e );
	    client->Init( &e );

	    // Pass any errors down to the UI, so they'll get picked up.
	    if ( e.Test() ) 
		ui->HandleError( &e );
	}
    }
}

//
// Convert a spec in string form into a hash and return a reference to that
// hash.
//
SV *
PerlClientApi::ParseSpec( const char *type, const char *form )
{
    if( P4PERL_DEBUG_FORMS )
	printf( "[ParseSpec]: Parsing a %s spec. Form is:\n%s\n", 
		type, form );

    if( !IsParseForms() )
    {
	warn( "P4::ParseSpec() requires ParseForms mode" );
	return &PL_sv_undef;
    }

    StrPtr	*specDef = FetchSpecDef( type );

    if ( !specDef )
    {
	StrBuf m;
	m = "P4::ParseSpec(): No spec definition for ";
	m.Append( type );
	m.Append( " objects." );
	warn( m.Text() );
	return &PL_sv_undef;
    }

    // Got a specdef so now we can attempt to parse it.
    
    SpecDataTable	specData;
    Spec		s( specDef->Text(), "" );
    Error		e;

    s.ParseNoValid( form, &specData, &e );
    if ( e.Test() )
    {
	//
	// Report the error through the UI interface
	//
	ui->HandleError( &e );
	return &PL_sv_undef;
    }

    // Now we've parsed it, convert it into a hash. We do that via 
    // direct access to the method in PerlClientUser - this is ugly, but
    // expedient.

    return ui->DictToHash( specData.Dict(), specDef );

}

//
// Convert a spec in hash form into its string representation
//
SV *
PerlClientApi::FormatSpec( const char *type, HV *hash )
{
    if( P4PERL_DEBUG_FORMS )
	printf( "[FormatSpec]: Formatting a %s spec\n" );

    if( !IsParseForms() )
    {
	warn( "P4::FormatSpec() requires ParseForms mode to format specs." );
	return &PL_sv_undef;
    }

    StrPtr	*specDef = FetchSpecDef( type );

    if ( !specDef )
    {
	StrBuf m;
	m = "P4::FormatSpec(): No spec definition for ";
	m.Append( type );
	m.Append( " objects." );
	warn( m.Text() );
	return &PL_sv_undef;
    }

    // Got a specdef so now we can attempt to convert. We do the conversion
    // using nasty direct access to the method in PerlClientUser for now. 
    // Really these conversion functions should be somewhere more global.
    StrBuf	buf;
    if( ui->HashToForm( hash, &buf, specDef ) )
    {
	if( P4PERL_DEBUG_FORMS )
	    printf( "[FormatSpec]: Result was: \n%s\n", buf.Text() );

	return newSVpv( buf.Text(), buf.Length() );
    }
    
    StrBuf m;
    m = "P4::FormatSpec(): Error converting hash to a string.";
    warn( m.Text() );
    return &PL_sv_undef;
}


//
// Fetch a spec definition from the cache - faulting it if it's not there.
//

StrPtr * 
PerlClientApi::FetchSpecDef( const char *type )
{
    StrPtr *sd = specDict.GetVar( type );
    if( sd ) return sd;

    // Fault. Now we have to do something nasty. We're in parse_forms mode, so 
    // we can run a "p4 XXXX -o" and discard the result - the specdef should 
    // now be in the cache. 

    char * const argv[] = { "-o" };
    Run( type, 1, argv );

    sd = specDict.GetVar( type );
    if( sd ) return sd;

    // OK, now we're hosed. 

    return 0;
}
