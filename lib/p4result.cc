/*******************************************************************************

Copyright (c) 1997-2004, Perforce Software, Inc.  All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1.  Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

2.  Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTR
IBUTORS "AS IS"
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


/*******************************************************************************
 * Name		: p4result.cc
 *
 * Author	: Tony Smith <tony@perforce.com> or <tony@smee.org>
 *
 * Description	: Ruby class for holding results of Perforce commands 
 *
 ******************************************************************************/
#include <clientapi.h>

#ifdef OS_NT
# include <math.h>
#endif

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

#include "p4perldebug.h"
#include "p4result.h"

P4Result::P4Result()
{
    merged = 0;
    debug  = 0;
    output = newAV();
    errors = newAV();
    warnings = newAV();
}

P4Result::~P4Result()
{
    Clear();
}

void
P4Result::Clear()
{
    av_undef( output );
    av_undef( warnings );
    av_undef( errors );
}

void
P4Result::Reset(int merge)
{
    if( P4PERL_DEBUG_FLOW )
	printf( "[P4Result::Reset]: Discarding previous results\n" );

    merged = merge;
    Clear();

    output = newAV();
    warnings = newAV();
    errors = newAV();
}

void
P4Result::AddOutput( const char *msg )
{
    if( P4PERL_DEBUG_DATA )
	printf( "[P4Result::AddOutput]: %s\n", msg );

    av_push( output, newSVpv( msg, 0 ) );
}

void
P4Result::AddOutput( SV * out )
{
    if( P4PERL_DEBUG_DATA )
	printf( "[P4Result::AddOutput]: (perl object)\n" );

    av_push( output, out );
}

void
P4Result::AddError( Error *e )
{
    StrBuf	m;
    e->Fmt( &m );

    int s;
    s = e->GetSeverity();

    // 
    // Empty and informational messages are pushed out as output as nothing
    // worthy of error handling has occurred. Warnings go into the warnings
    // list and the rest are lumped together as errors.
    //

    if ( s == E_EMPTY || s == E_INFO )
    {
	AddOutput( m.Text() );
	return;
    }

    if( P4PERL_DEBUG_DATA )
	printf( "[P4Result::AddError]: %s\n", m.Text() );

    if ( s == E_WARN && !merged )
	av_push( warnings, newSVpv( m.Text(), 0 ) );
    else
	av_push( errors, newSVpv( m.Text(), 0 ) );
}

I32
P4Result::OutputCount()
{
    return av_len( output ) + 1;
}


I32
P4Result::ErrorCount()
{
    return av_len( errors ) + 1;
}

I32
P4Result::WarningCount()
{
    return av_len( warnings ) + 1;
}

