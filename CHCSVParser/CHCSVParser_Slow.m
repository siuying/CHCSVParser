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

@end

#define SETSTATE(_s) if (state != CHCSVParserStateCancelled) { state = _s; }

@implementation CHCSVParser_Slow

#pragma mark Parsing methods

- (NSRange)_rangeOfNextCharacter {
    if (stringIndex >= [currentString length] / 2) {
        [self readNextChunk];
    }
    
    if (stringIndex >= [currentString length]) { return NSMakeRange(NSNotFound, 0); }
    
    return [currentString rangeOfComposedCharacterSequenceAtIndex:stringIndex];
}

- (NSString *)_nextCharacter {
    NSRange r = [self _rangeOfNextCharacter];
    if (r.location == NSNotFound) { return nil; }
    
    NSString *next = [currentString substringWithRange:r];
    stringIndex = r.location + r.length;
    
    return next;
}

- (NSString *)_peekNextCharacter {
    NSRange r = [self _rangeOfNextCharacter];
    if (r.location == NSNotFound) { return nil; }
    
    return [currentString substringWithRange:r];
}

- (void)_parseLines {
    NSString *peek = [self _peekNextCharacter];
    while (peek != nil) {
        NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];
        
        [self _beginLine];
        [self _parseFields];
        [self _endLine];
        
        [p drain];
        
        peek = [self _peekNextCharacter];
    }
}

#define IS_NEWLINE_CHAR(_s) ([[self newlineCharacterSet] characterIsMember:[(_s) characterAtIndex:0]])

- (void)_parseFields {
    NSString *next = [self _peekNextCharacter];
    
    while (!IS_NEWLINE_CHAR(next) && next != nil) {
        if ([next isEqualToString:@"#"]) {
            [self _parseComment];
        } else {
            [self _parseField];
        }
        // this consumes the delimiter/newline
        next = [self _nextCharacter];
    }

}

- (void)_parseField {
    NSString *current = [self _peekNextCharacter];
    NSInteger startIndex = stringIndex;
    
    BOOL balancedQuotes = YES;
    BOOL balancedEscapes = YES;
    
    if ([current isEqualToString:@"\""]) {
        balancedQuotes = NO;
        (void)[self _nextCharacter]; // skip the quote
        current = [self _peekNextCharacter];
    }
    
    while (current != nil) {
        if (balancedQuotes == YES && balancedEscapes == YES) {
            if ([current isEqualToString:[self delimiter]]) { break; }
            if (IS_NEWLINE_CHAR(current)) { break; }
        }
        
        current = [self _nextCharacter];
        
        if ([current isEqualToString:@"\""]) {
            if (!balancedEscapes) {
                balancedEscapes = YES;
            } else {
                balancedQuotes = !balancedQuotes;
            }
        } else if ([current isEqualToString:@"\\"]) {
            balancedEscapes = !balancedEscapes;
        } else {
            balancedEscapes = YES;
        }
        
        current = [self _peekNextCharacter];
    }
    
    NSUInteger endIndex = stringIndex;
    NSRange fieldRange = NSMakeRange(startIndex, endIndex - startIndex);
    NSString *field = [currentString substringWithRange:fieldRange];
    [self _readField:field];
}

- (void)_parseComment {
    NSUInteger startIndex = stringIndex;
    NSString *current = nil;
    
    // read up to the end of the line/file
    while ((current = [self _peekNextCharacter]) && current != nil && !IS_NEWLINE_CHAR(current)) {
        (void)[self _nextCharacter];
    }
    
    NSUInteger endIndex = stringIndex;
    NSRange commentRange = NSMakeRange(startIndex, endIndex - startIndex);
    NSString *comment = [currentString substringWithRange:commentRange];
    [self _readComment:comment];
}

- (NSString *)_fieldByCleaningField:(NSString *)rawField {
    NSUInteger length = [rawField length];
    NSMutableString *field = [[NSMutableString alloc] initWithCapacity:length];
    NSUInteger index = 0;
    
    BOOL skippedLastTime = NO;
    
    while (index < length) {
        NSRange r = [rawField rangeOfComposedCharacterSequenceAtIndex:index];
        NSString *character = [rawField substringWithRange:r];
        
        BOOL shouldAppend = YES;
        
        if ([character isEqualToString:@"\""]) {
            if (index == 0 || (r.location + r.length >= length)) {
                shouldAppend = NO;
                // this is the first/last character; skip it
            } else if (r.location + r.length < length) {
                NSRange nextRange = [rawField rangeOfComposedCharacterSequenceAtIndex:r.location + r.length];
                NSString *next = [rawField substringWithRange:nextRange];
                if ([next isEqualToString:character]) {
                    // quote escaped by double-quoting
                    // skip this one
                    shouldAppend = NO;
                }
            }
        } else if ([character isEqualToString:@"\\"]) {
            if (r.location + r.length < length) {
                shouldAppend = NO;
            }
        }
        
        if (shouldAppend || skippedLastTime == YES) {
            [field appendString:character];
            skippedLastTime = NO;
        } else {
            skippedLastTime = YES;
        }
        
        index = r.location + r.length;
    }
    
    return [field autorelease];
}

@end
