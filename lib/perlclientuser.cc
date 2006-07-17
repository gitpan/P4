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
 * Name		: perlclientuser.cc
 *
 * Author	: Tony Smith <tony@perforce.com> or <tony@smee.org>
 *
 * Description	: Perl bindings for the Perforce API. User interface class
 * 		  for getting Perforce results into Perl.
 *
 ******************************************************************************/
/*
 * Include math.h here because it's included by some Perl headers and on
 * Win32 it must be included with C++ linkage. Including it here prevents it
 * from being reincluded later when we include the Perl headers with C linkage.
 */
#ifdef OS_NT
#  include <math.h>
#endif

#include <clientapi.h>
#include <spec.h>
#include <diff.h>

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


/*******************************************************************************
 * PerlClientUser - the user interface part. Gets responses from the Perforce
 * server, and converts the data to Perl format for returning to the caller.
 ******************************************************************************/

PerlClientUser::PerlClientUser()
{ 
    debug = 0;
    input = 0;
}


void
PerlClientUser::Reset(int merged )
{
    results.Reset( merged );
    lastSpecDef.Clear();

    // Leave input alone.
}

void	
PerlClientUser::Finished()
{
    // Reset input coz we should be done with it now. Decrement the ref count
    // so it can be reclaimed.
    if ( P4PERL_DEBUG_FLOW && input )
	printf( "[PerlClientUser::Finished] Cleaning up saved input\n" );

    if( input )
    {
	sv_2mortal( input );
	input = 0;
    }
}

void
PerlClientUser::HandleError( Error *e )
{
    if( P4PERL_DEBUG_FLOW )
	printf( "[PerlClientUser:HandleError]: Received error\n" );

    results.AddError( e );
}

void
PerlClientUser::OutputText( const_char *data, int length )
{
    if ( P4PERL_DEBUG_FLOW )
	printf( "[PerlClientUser::OutputText]: Received %d bytes\n", length );

    results.AddOutput( data );
}

void
PerlClientUser::OutputInfo( char level, const_char *data )
{
    if ( P4PERL_DEBUG_FLOW )
	printf( "[PerlClientUser::OutputInfo]: Received data\n" );

    results.AddOutput( data );
}

void
PerlClientUser::OutputBinary( const_char *data, int length )
{
    if ( P4PERL_DEBUG_FLOW )
	printf( "[PerlClientUser::OutputBinary]: Received %d bytes\n", length );

    //
    // Binary is just stored in a string. Since the char * version of
    // P4Result::AddOutput() assumes it can strlen() to find the length,
    // we'll make the String object here.
    //
    results.AddOutput( sv_2mortal( newSVpv( data, length) ) );
}

void
PerlClientUser::OutputStat( StrDict *values )
{
    StrPtr	*spec, *data;

    // If both specdef and data are set, then we need to parse the form
    // and return the results. If not, then we just convert it as is.

    spec = values->GetVar( "specdef" );
    data = values->GetVar( "data" );

    if( P4PERL_DEBUG_FLOW )
	printf( "[PerlClientUser::OutputStat]: Received tagged output\n" );

    //
    // Save the spec definition for later retrieval by P4ClientApi
    //
    if( spec )
	lastSpecDef = spec->Text();

    if ( spec && data )
    {
	if ( P4PERL_DEBUG_FORMS )
	    printf( "[PerlClientUser::OutputStat]: Parsing form\n" );


	// Parse up the form. Use the ParseNoValid() interface to prevent
	// errors caused by the use of invalid defaults for select items in
	// jobspecs.
	SpecDataTable	specData;
	Spec		s( spec->Text(), "" );
	Error		e;

	s.ParseNoValid( data->Text(), &specData, &e );
	if ( e.Test() )
	{
	    HandleError( &e );
	    return;
	}

	results.AddOutput( DictToHash( specData.Dict(), spec ) );
    }
    else
    {
	results.AddOutput( DictToHash( values, NULL ) );
    }
}


/*
 * Diff support for Perl API. Since the Diff class only writes its output
 * to files, we run the requested diff putting the output into a temporary
 * file. Then we read the file in and add its contents line by line to the 
 * results.
 */

void
PerlClientUser::Diff( FileSys *f1, FileSys *f2, int doPage, 
				char *diffFlags, Error *e )
{

    if ( P4PERL_DEBUG_FLOW )
	printf( "[PerlClientUser::Diff]: Comparing files\n" );

    //
    // Duck binary files. Much the same as ClientUser::Diff, we just
    // put the output into Perl space rather than stdout.
    //
    if( !f1->IsTextual() || !f2->IsTextual() )
    {
	if ( f1->Compare( f2, e ) )
	    results.AddOutput( "(... files differ ...)" );
	return;
    }

    // Time to diff the two text files. Need to ensure that the
    // files are in binary mode, so we have to create new FileSys
    // objects to do this.

    FileSys *f1_bin = FileSys::Create( FST_BINARY );
    FileSys *f2_bin = FileSys::Create( FST_BINARY );
    FileSys *t = FileSys::CreateGlobalTemp( f1->GetType() );

    f1_bin->Set( f1->Name() );
    f2_bin->Set( f2->Name() );

    {
	//
	// In its own block to make sure that the diff object is deleted
	// before we delete the FileSys objects.
	//
#ifndef OS_NEXT
	::
#endif
	Diff d;

	d.SetInput( f1_bin, f2_bin, diffFlags, e );
	if ( ! e->Test() ) d.SetOutput( t->Name(), e );
	if ( ! e->Test() ) d.DiffWithFlags( diffFlags );
	d.CloseOutput( e );

	// OK, now we have the diff output, read it in and add it to 
	// the output.
	if ( ! e->Test() ) t->Open( FOM_READ, e );
	if ( ! e->Test() ) 
	{
	    StrBuf 	b;
	    while( t->ReadLine( &b, e ) )
		results.AddOutput( b.Text() );
	}
    }

    delete t;
    delete f1_bin;
    delete f2_bin;

    if ( e->Test() ) HandleError( e );
}


/*
 * Prompt the user for input
 */
void
PerlClientUser::Prompt( const StrPtr &msg, StrBuf &rsp, int noEcho, Error *e )
{
    if ( P4PERL_DEBUG_FLOW )
	printf( "[PerlClientUser::Prompt]: Using supplied input\n" );

    InputData( &rsp, e );
}

/*
 * convert input from the user into a form digestible to Perforce. This
 * involves either (a) converting any supplied hash to a Perforce form, or
 * (b) reading whatever we were given as a string.
 */

void
PerlClientUser::InputData( StrBuf *strbuf, Error *e )
{
    if ( P4PERL_DEBUG_FLOW )
	printf( "[PerlClientUser::InputData]: Using supplied input\n" );

    if( ! input )
    {
	warn( "InputData() called with no supplied input" );
	return;
    }

    //
    // Check that what we've got is a reference. It really ought to be 
    // because of the way SetInput is coded, but just to make sure.
    //
    if( ! SvROK( input ) )
    {
	warn( "Bad input data encountered! What did you pass to SetInput()?" );
	return;
    }

    // 
    // Now de-reference it and try to figure out if we're looking at a PV, 
    // an HV, or an AV. If it's an array, then it may be an array of PVs or
    // an array of HVs, so we shift it by one and use the first element.
    //
    SV *s = SvRV( input );
    if( SvTYPE( s ) == SVt_PVAV )
    {
	s = av_shift( (AV *) s );
	if( !s )
	{
	    warn( "InputData() ran out of input for Perforce command" );
	    return;
	}
    }

    if( SvTYPE( s ) == SVt_PVHV )
    {
	HashToForm( (HV *)s, strbuf );
	return;
    } 

    // Otherwise, we assume it's a string - a reasonable assumption
    strbuf->Set( SvPV_nolen( s ) );
}

/*
 * Accept input from Perl for later use. We just save what we're given here 
 * because we may not have the specdef available to parse it with at this time.
 * To deal with Perl's horrible reference count system, we create a new 
 * reference here to whatever we're given. That way we'll increment the
 * reference count of the object when it's given to us, and we have to
 * decrement the refcount when we're done with this object. Ugly, but hey,
 * that's Perl!
 */

void
PerlClientUser::SetInput( SV * i )
{
    if ( P4PERL_DEBUG_FLOW )
	printf( "[PerlClientUser::SetInput]: Stashing input for later\n" );

    SV *t = i;
    if( SvROK( i ) )
	t = SvRV( i );

    input = newRV( t );
}


/*
 * Convert a Perforce StrDict into a Perl hash. Convert multi-level 
 * data (Files0, Files1 etc. ) into (nested) array members of the hash. If
 * specDef is NULL, then the specDef member will be skipped over, other
 * wise it will be saved as a wrapped structure in the hash.
 */

SV *
PerlClientUser::DictToHash( StrDict *d, StrPtr *specDef )
{
    AV		*av = 0;
    SV		*rv = 0;
    SV		**svp = 0;
    HV		*hv = newHV();
    int		i;
    int		seq;
    StrBuf	key;
    StrRef	var, val;
    StrPtr	*data = d->GetVar( "data" );

    if( P4PERL_DEBUG_FLOW )
    	printf( "[PerlClientUser::DictToHash]: Converting dictionary to hash\n" );

    for( i = 0; d->GetVar( i, var, val ); i++ )
    {
	// Ignore special variables
	if( var == "specdef" || var == "func" || var == "specFormatted" ) 
	    continue;

	InsertItem( hv, &var, &val );
    }

    //
    // We return a reference to the HV, but we mustn't increment the
    // reference count since this will be the sole reference to this HV, at
    // least as far as this method is concerned.
    //
    return newRV_noinc( (SV *)hv );
}


//
// Convert a perl hash into a flat Perforce form.
//
int
PerlClientUser::HashToForm( HV *hv, StrBuf *b, StrPtr *specdef )
{
    HV		*flatHv = 0;

    if ( P4PERL_DEBUG_FORMS )
	printf( "[PerlClientUser::HashToForm]: Converting hash to form.\n" );

    if( !specdef )
	specdef = varList->GetVar( "specdef" );

    if( !specdef )
    {
	warn( "No specdef available. Cannot convert hash to a Perforce form" );
	return 0;
    }

    /*
     * Also need now to go through the hash looking for AV elements
     * as they need to be flattened before parsing. Yuk!
     */
    if ( ! ( flatHv = FlattenHash( hv ) ) )
    {
	warn( "Failed to convert Perl hash to Perforce form");
	return 0;
    }

    if ( P4PERL_DEBUG_FORMS )
	printf( "HashToForm: Flattened hash input.\n" );

    SpecDataTable	specData;
    Spec		s( specdef->Text(), "" );

    char	*key;
    SV		*val;
    I32		klen;

    for ( hv_iterinit( flatHv ); val = hv_iternextsv( flatHv, &key, &klen ); )
    {
	if ( !SvPOK( val ) ) continue;
	specData.Dict()->SetVar( key, SvPV_nolen( val ) );
    }

    s.Format( &specData, b );

    if ( P4PERL_DEBUG_FORMS )
	printf( "[PerlClientUser::HashToForm]: Converted form:\n%s\n", b->Text() );

    return 1;
}

/*
 * Split a key into its base name and its index. i.e. for a key "how1,0"
 * the base name is "how" and they index is "1,0"
 */

void
PerlClientUser::SplitKey( const StrPtr *key, StrBuf &base, StrBuf &index )
{
    int i;

    base = *key;
    index = "";
    // Start at the end and work back till we find the first char that is
    // neither a digit, nor a comma. That's the split point.
    for ( i = key->Length(); i;  i-- )
    {
	char prev = (*key)[ i-1 ];
	if ( !isdigit( prev ) && prev != ',' )
	{
	    base.Set( key->Text(), i );
	    index.Set( key->Text() + i );
	    break;
	}
    }
}

/*
 * Insert an element into the response structure. The element may need to
 * be inserted into an array nested deeply within the enclosing hash.
 */

void
PerlClientUser::InsertItem( HV *hv, const StrPtr *var, const StrPtr *val )
{
    SV		**svp = 0;
    AV		*av = 0;
    StrBuf	base, index;
    StrRef	comma( "," );

    if ( P4PERL_DEBUG_DATA )
	printf( "[PerlClientUser::InsertItem]: key %s, value %s \n", 
			var->Text(), val->Text() );

    SplitKey( var, base, index );

    if ( P4PERL_DEBUG_FORMCONV )
	printf( "\tbase=%s, index=%s\n", base.Text(), index.Text() );


    // If there's no index, then we insert into the top level hash 
    // but if the key is already defined then we need to rename the key. This
    // is probably one of those special keys like otherOpen which can be
    // both an array element and a scalar. The scalar comes last, so we
    // just rename it to "otherOpens" to avoid trashing the previous key
    // value
    if ( index == "" )
    {
	svp = hv_fetch( hv, base.Text(), base.Length(), 0 );
	if ( svp )
	    base.Append( "s" );

	if ( P4PERL_DEBUG_FORMCONV )
	    printf( "\tCreating new scalar hash member %s\n", base.Text() );
	hv_store( hv, base.Text(), base.Length(), 
	     newSVpv( val->Text(), val->Length() ), 0 );
	return;
    }

    //
    // Get or create the parent AV from the hash.
    //
    svp = hv_fetch( hv, base.Text(), base.Length(), 0 );
    if ( ! svp ) 
    {
	if ( P4PERL_DEBUG_FORMCONV )
	    printf( "\tCreating new array hash member %s\n", base.Text() );

	av = newAV();
	hv_store( hv, base.Text(), base.Length(), newRV( (SV*)av) ,0 );
    }

    //
    // If they key already exists, but the value is not a reference,
    // then this means we need to convert a previously scalar hash
    // member into an array hash member: yuk. It seems this happens
    // on 'p4 diff2' which produces 'type'/'type2' type members instead of
    // 'type1'/'type2' members. Very annoying.
    //
    if ( svp && !SvROK( *svp ) )
    {
	SV *	sv;

	if ( P4PERL_DEBUG_FORMCONV )
	    printf( "\tConverting value for %s from scalar to array.\n", base.Text() );
	//
	// For some reason simply moving the SV out of the hash and into
	// the array doesn't work. Hence we're creating a copy...
	//
	av = newAV();
	sv = newSVpv( SvPV( *svp, PL_na ), 0 );
	av_push( av, sv );

	// Now delete the existing value and have its refcount decremented
	hv_delete( hv, base.Text(), base.Length(), G_DISCARD );

	// Store the new entry and refetch it so that svp is correctly set
	hv_store( hv, base.Text(), base.Length(), newRV( (SV*)av ), 0 );
	svp = hv_fetch( hv, base.Text(), base.Length(), 0 );
    }

    if ( svp && SvROK( *svp ) )
	av = (AV *) SvRV( *svp );

    // The index may be a simple digit, or it could be a comma separated
    // list of digits. For each "level" in the index, we need a containing
    // AV and an HV inside it.
    if ( P4PERL_DEBUG_FORMCONV )
	printf( "\tFinding correct index level...\n" );

    for( const char *c = 0 ; c = index.Contains( comma ); )
    {
	StrBuf	level;
	level.Set( index.Text(), c - index.Text() );
	index.Set( c + 1 );

	// Found another level so we need to get/create a nested AV
	// under the current av. If the level is "0", then we create a new
	// one, otherwise we just pop the most recent AV off the parent
	
	if ( P4PERL_DEBUG_FORMCONV )
	    printf( "\t\tgoing down...\n" );

	svp = av_fetch( av, level.Atoi(), 0 );
	if ( ! svp )
	{
	    AV *tav = newAV();
	    av_store( av, level.Atoi(), newRV( (SV*)tav) );
	    av = tav;
	}
	else
	{
	    if ( ! SvROK( *svp ) )
	    {
		warn( "Not an array reference." );
		return;
	    }

	    if ( SvTYPE( SvRV( *svp ) ) != SVt_PVAV )
	    {
		warn( "Not an array reference." );
		return;
	    }

	    av = (AV *) SvRV( *svp );
	}
    }
    if ( P4PERL_DEBUG_FORMCONV )
	printf( "\tInserting value %s\n", val->Text() );

    av_push( av, newSVpv( val->Text(), 0 ) );
}

// Flatten array elements in a hash into something Perforce can parse.

HV * 
PerlClientUser::FlattenHash( HV *hv )
{
    HV 		*fl;
    SV		*val;
    char	*key;
    I32		klen;

    if ( P4PERL_DEBUG_FORMCONV )
	printf( "[PerlClientUser::FlattenHash]: Flattening hash contents\n" );

    fl = (HV *)sv_2mortal( (SV *)newHV() );
    for ( hv_iterinit( hv ); val = hv_iternextsv( hv, &key, &klen ); )
    {
	if ( SvROK( val ) )
	{
	    /* Objects are not permitted in forms. Like it or lump it */

	    if ( sv_isobject( val ) )
	    {
		StrBuf msg;

		msg << key << " field contains an object. " <<
			"Perforce forms may not contain Perl objects. " 
			"Permitted types are strings, numbers and arrays";

		warn( msg.Text() );
		return NULL;
	    }

	    if ( SvTYPE( SvRV( val ) ) == SVt_PVAV ) 
	    {
		if ( P4PERL_DEBUG_FORMCONV )
		    printf( "\tFlattening %s array\n", key );

		// Flatten this array by constructing keys from the parent
		// hash key and the array index
		AV	*av = (AV *)SvRV( val );
		for ( int i = 0; i <= av_len( av ); i++ )
		{
		    StrBuf	newKey;

		    if ( P4PERL_DEBUG_FORMCONV )
			printf( "\t\tParsing element %d\n", i );

		    SV	**elem = av_fetch( av, i, 0 );

		    if ( ! elem )
		    {
			StrBuf	msg;
			msg << key << " field contains a bizarre array. " <<
			       "Array elements may only contain strings " <<
			       "and numbers.";

			warn( msg.Text() );
			return NULL;
		    }

		    if ( P4PERL_DEBUG_FORMCONV )
			printf( "\t\tFetched element %d\n", i );

		    newKey.Set( key );
		    newKey << i;

		    if ( P4PERL_DEBUG_FORMCONV )
			printf( "\t\tFormatted element %d( %s )\n", i, newKey.Text() );


		    hv_store( fl, newKey.Text(), newKey.Length(), 
			    SvREFCNT_inc(*elem), 0 );

		    if ( P4PERL_DEBUG_FORMCONV )
			printf( "\t\tStored element %d\n", i );

		}
	    }
	}
	else
	{
	    if ( P4PERL_DEBUG_FORMCONV )
		printf( "\tStoring non-array member %s\n", key );

	    // Just store the element as is
	    hv_store( fl, key, klen, SvREFCNT_inc(val), 0 );
	}
    }
    return fl;
}

