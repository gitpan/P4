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
 * Name		: p4result.h
 *
 * Author	: Tony Smith <tony@perforce.com> or <tony@smee.org>
 *
 * Description	: C++ class for holding results of Perforce commands 
 *
 ******************************************************************************/

class P4Result
{
    public:

    P4Result();
    ~P4Result();
    
    // Setting
    void	AddOutput( const char *msg );
    void	AddOutput( SV * out );
    void	AddError( Error *e );

    // Getting
    AV *	GetOutput()	{ return output;	}
    AV *	GetErrors()	{ return errors;	}
    AV *	GetWarnings()	{ return warnings;	}

    // Testing
    I32		OutputCount();
    I32		ErrorCount();
    I32		WarningCount();

    // Clear previous results
    void	Reset(int merge=0);

    // Debugging Support
    void	SetDebugLevel( int i )	{ debug = i;	}

    private:
    void	Clear();

    private:
    int		merged;
    int		debug;
    AV *	output;
    AV *	warnings;
    AV *	errors;
};
