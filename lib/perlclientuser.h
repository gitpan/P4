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
 * Name		: perlclientuser.h
 *
 * Author	: Tony Smith <tony@perforce.com> or <tony@smee.org>
 *
 * Description	: Perl bindings for the Perforce API. User interface class
 * 		  for getting Perforce results into Perl.
 *
 ******************************************************************************/

/*******************************************************************************
 * PerlClientUser - the user interface part. Gets responses from the Perforce
 * server, and converts the data to Perl format for returning to the caller.
 ******************************************************************************/
class PerlClientUser : public ClientUser
{
    public:
	PerlClientUser();

	// Client User methods overridden here
	void	HandleError( Error *e );
	void    OutputText( const_char *data, int length );
	void    OutputInfo( char level, const_char *data );
	void	OutputStat( StrDict *values );
	void    OutputBinary( const_char *data, int length );
	void	InputData( StrBuf *strbuf, Error *e );
	void	Diff( FileSys *f1, FileSys *f2, int doPage, 
				char *diffFlags, Error *e );
	void	Prompt( const StrPtr &msg, StrBuf &rsp, 
				int noEcho, Error *e );

	void	Finished();

	// Local methods
	void	 	SetInput( SV * i );
	P4Result& 	GetResults()		{ return results;	} 
	I32	 	ErrorCount();
	void	 	Reset(int merged = 0);
	StrPtr & 	LastSpecDef()		{ return lastSpecDef;	}

	// Debugging support
	void		SetDebugLevel( int d )	
	{ 
	    debug = d; 
	    results.SetDebugLevel( d );
	}

	// Spec parsing support. Used by PerlClientApi directly as well as 
	// via ClientUser interfaces.
	int		HashToForm( HV *i, StrBuf *strbuf, StrPtr * specdef=0 );
	SV *		DictToHash( StrDict *form, StrPtr *specDef );

    private:
	void	SplitKey( const StrPtr *key, StrBuf &base, StrBuf &index );
	void	InsertItem( HV * hash, const StrPtr *var, const StrPtr *val );
	HV * 	FlattenHash( HV *hv );

    private:
	P4Result	results;
	StrBuf		lastSpecDef;
	SV *		input;
	int		debug;
};

