//
//  CHCSVParser.m
//  CHCSVParser
/**
 Copyright (c) 2010 Dave DeLong
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 **/

#import "CHCSV.h"
#import "CHCSVParser_Slow.h"
#import "CHCSVParser_Internal.h"
#import "CHCSVTypes.h"

#define STRING_QUOTE @"\""
#define STRING_BACKSLASH @"\\"

#define UNICHAR_QUOTE '"'
#define UNICHAR_BACKSLASH '\\'

@interface NSMutableString (CHCSVAdditions)

- (void) trimString_csv:(NSString *)character;
- (void) trimCharactersInSet_csv:(NSCharacterSet *)set;
- (void) replaceOccurrencesOfString:(NSString *)find withString_csv:(NSString *)replace;

@end

@implementation NSMutableString (CHCSVAdditions)

- (void) trimString_csv:(NSString *)character {
	[self replaceCharactersInRange:NSMakeRange(0, [character length]) withString:@""];
	[self replaceCharactersInRange:NSMakeRange([self length] - [character length], [character length]) withString:@""];
}

- (void) trimCharactersInSet_csv:(NSCharacterSet *)set {
	NSString *trimmed = [self stringByTrimmingCharactersInSet:set];
	[self setString:trimmed];
}

- (void) replaceOccurrencesOfString:(NSString *)find withString_csv:(NSString *)replace {
	[self replaceOccurrencesOfString:find withString:replace options:NSLiteralSearch range:NSMakeRange(0, [self length])];
}

@end

@interface CHCSVParser_Slow ()

- (void) readNextChunk;
- (NSString *) nextCharacter;
- (void) runParseLoop;
- (void) processComposedCharacter:(NSString *)currentCharacter previousCharacter:(NSString *)previousCharacter previousPreviousCharacter:(NSString *)previousPreviousCharacter;

- (void) beginCurrentLine;
- (void) beginCurrentField;
- (void) finishCurrentField;
- (void) finishCurrentLine;

@end

#define SETSTATE(_s) if (state != CHCSVParserStateCancelled) { state = _s; }

@implementation CHCSVParser_Slow

- (id)initWithStream:(NSInputStream *)readStream encoding:(NSStringEncoding)e initialBytes:(uint8_t *)firstFour error:(NSError **)anError {
    self = [super _initWithStream:readStream encoding:e initialBytes:firstFour error:anError];
    if (self) {        
		balancedQuotes = YES;
		balancedEscapes = YES;
		
		currentLine = 0;
		currentField = [[NSMutableString alloc] init];
		
        if (currentChunk == nil) {
            currentChunk = [[NSMutableData alloc] init];
        }
		endOfStreamReached = NO;
        currentChunkString = [[NSMutableString alloc] init];
		stringIndex = 0;
		
        SETSTATE(CHCSVParserStateInsideFile)
        
    }
    return self;
}

- (void) dealloc {
	[currentField release];
	[currentChunk release];
	[currentChunkString release];
	[error release];
	[delimiter release];
	
	[super dealloc];
}

#pragma mark Parsing methods

- (NSString *) nextCharacter {
	if (endOfStreamReached == NO && stringIndex >= [currentChunkString length]/2) {
        [self readNextChunk];
	}
	
	if (stringIndex >= [currentChunkString length]) { return nil; }
	if ([currentChunkString length] == 0) { return nil; }
	
	NSRange charRange = [currentChunkString rangeOfComposedCharacterSequenceAtIndex:stringIndex];
	NSString *nextChar = [currentChunkString substringWithRange:charRange];
	stringIndex = charRange.location + charRange.length;
	return nextChar;
}

- (void) parse {
	hasStarted = YES;
	[[self parserDelegate] parser:self didStartDocument:[self csvFile]];
	
	[self runParseLoop];
	
	if (error != nil) {
		[[self parserDelegate] parser:self didFailWithError:error];
	} else {
		[[self parserDelegate] parser:self didEndDocument:[self csvFile]];
	}
	hasStarted = NO;
}

- (void) runParseLoop {
	NSString *currentCharacter = nil;
	NSString *previousCharacter = nil;
	NSString *previousPreviousCharacter = nil;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	unsigned char counter = 0;
	
	while (error == nil && 
		   (currentCharacter = [self nextCharacter]) && 
		   currentCharacter != nil) {
		[self processComposedCharacter:currentCharacter previousCharacter:previousCharacter previousPreviousCharacter:previousPreviousCharacter];
        
        if (state == CHCSVParserStateCancelled) { break; }
        
		previousPreviousCharacter = previousCharacter;
		previousCharacter = currentCharacter;
		
		counter++;
		if (counter == 0) { //this happens every 256 (2**8) iterations when the unsigned short overflows
			[currentCharacter retain];
			[previousCharacter retain];
			[previousPreviousCharacter retain];
			
			[pool drain];
			pool = [[NSAutoreleasePool alloc] init];
			
			[currentCharacter autorelease];
			[previousCharacter autorelease];
			[previousPreviousCharacter autorelease];
		}
	}
	
	[pool drain];
	
	if ([currentField length] > 0 && state == CHCSVParserStateInsideField) {
		[self finishCurrentField];
	}
	if (state == CHCSVParserStateInsideLine) {
		[self finishCurrentLine];
	}
}

- (void) processComposedCharacter:(NSString *)currentCharacter previousCharacter:(NSString *)previousCharacter previousPreviousCharacter:(NSString *)previousPreviousCharacter {
	if (state == CHCSVParserStateInsideFile) {
		//this is the "beginning of the line" state
		//this is also where we determine if we should ignore this line (it's a comment)
		if ([currentCharacter isEqual:@"#"] == NO) {
			[self beginCurrentLine];
		} else {
            SETSTATE(CHCSVParserStateInsideComment)
		}
	}
	
	unichar currentUnichar = [currentCharacter characterAtIndex:0];
	unichar previousUnichar = [previousCharacter characterAtIndex:0];
	unichar previousPreviousUnichar = [previousPreviousCharacter characterAtIndex:0];
	
	if (currentUnichar == UNICHAR_QUOTE) {
		if (state == CHCSVParserStateInsideLine) {
			//beginning a quoted field
			[self beginCurrentField];
			balancedQuotes = NO;
		} else if (state == CHCSVParserStateInsideField) {
			if (balancedEscapes == NO) {
				balancedEscapes = YES;
			} else {
				balancedQuotes = !balancedQuotes;
			}
		}
	} else if (currentUnichar == delimiterCharacter) {
		if (state == CHCSVParserStateInsideLine) {
			[self beginCurrentField];
			[self finishCurrentField];
		} else if (state == CHCSVParserStateInsideField) {
			if (balancedEscapes == NO) {
				balancedEscapes = YES;
			} else if (balancedQuotes == YES) {
				[self finishCurrentField];
			}
		}
	} else if (currentUnichar == UNICHAR_BACKSLASH) {
		if (state == CHCSVParserStateInsideField) {
			balancedEscapes = !balancedEscapes;
		} else if (state == CHCSVParserStateInsideLine) {
			[self beginCurrentField];
			balancedEscapes = NO;
		}
	} else if ([[NSCharacterSet newlineCharacterSet] characterIsMember:currentUnichar] && [[NSCharacterSet newlineCharacterSet] characterIsMember:previousUnichar] == NO) {
		if (balancedQuotes == YES && balancedEscapes == YES) {
			if (state != CHCSVParserStateInsideComment) {
				[self finishCurrentField];
				[self finishCurrentLine];
			} else {
                SETSTATE(CHCSVParserStateInsideFile)
			}
		}
	} else {
		if (previousUnichar == UNICHAR_QUOTE && previousPreviousUnichar != UNICHAR_BACKSLASH && balancedQuotes == YES && balancedEscapes == YES) {
			NSString *reason = [NSString stringWithFormat:@"Invalid CSV format on line #%lu immediately after \"%@\"", currentLine, currentField];
			error = [[NSError alloc] initWithDomain:CHCSVErrorDomain code:CHCSVErrorCodeInvalidFormat userInfo:[NSDictionary dictionaryWithObject:reason forKey:NSLocalizedDescriptionKey]];
			return;
		}
		if (state != CHCSVParserStateInsideComment) {
			if (state != CHCSVParserStateInsideField) {
				[self beginCurrentField];
			}
            SETSTATE(CHCSVParserStateInsideField)
			if (balancedEscapes == NO) {
				balancedEscapes = YES;
			}
		}
	}
	
	if (state != CHCSVParserStateInsideComment) {
		[currentField appendString:currentCharacter];
	}
}

- (void) beginCurrentLine {
	currentLine++;
	[[self parserDelegate] parser:self didStartLine:currentLine];
    SETSTATE(CHCSVParserStateInsideLine)
}

- (void) beginCurrentField {
	[currentField setString:@""];
	balancedQuotes = YES;
	balancedEscapes = YES;
    SETSTATE(CHCSVParserStateInsideField)
}

- (void) finishCurrentField {
	[currentField trimCharactersInSet_csv:[NSCharacterSet newlineCharacterSet]];
	if ([currentField hasPrefix:STRING_QUOTE] && [currentField hasSuffix:STRING_QUOTE]) {
		[currentField trimString_csv:STRING_QUOTE];
	}
	if ([currentField hasPrefix:delimiter]) {
		[currentField replaceCharactersInRange:NSMakeRange(0, [delimiter length]) withString:@""];
	}
	
	[currentField trimCharactersInSet_csv:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	[currentField replaceOccurrencesOfString:@"\"\"" withString_csv:STRING_QUOTE];
	
	//replace all occurrences of regex: \\(.) with $1 (but not by using a regex)
	NSRange nextSlash = [currentField rangeOfString:STRING_BACKSLASH options:NSLiteralSearch range:NSMakeRange(0, [currentField length])];
	while(nextSlash.location != NSNotFound) {
		[currentField replaceCharactersInRange:nextSlash withString:@""];
		
		NSRange nextSearchRange = NSMakeRange(nextSlash.location + nextSlash.length, 0);
		nextSearchRange.length = [currentField length] - nextSearchRange.location;
        if (nextSearchRange.location >= [currentField length]) { break; }
		nextSlash = [currentField rangeOfString:STRING_BACKSLASH options:NSLiteralSearch range:nextSearchRange];
	}
	
	NSString *field = [currentField copy];
	[[self parserDelegate] parser:self didReadField:field];
	[field release];
	
	[currentField setString:@""];
	
    SETSTATE(CHCSVParserStateInsideLine)
}

- (void) finishCurrentLine {
	[[self parserDelegate] parser:self didEndLine:currentLine];
    SETSTATE(CHCSVParserStateInsideFile)
}

#pragma Cancelling

- (void) cancelParsing {
    SETSTATE(CHCSVParserStateCancelled)
    error = [[NSError alloc] initWithDomain:CHCSVErrorDomain code:CHCSVErrorCodeParsingCancelled userInfo:nil];
}

@end
