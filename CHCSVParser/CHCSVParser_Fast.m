//
//  CHCSVParser_Fast.m
//  CHCSVParser
//
//  Created by Dave DeLong on 9/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "CHCSVParser_Fast.h"
#import "CHCSVParser_Internal.h"
#import "CHCSVTypes.h"

#define CHUNK_SIZE 1024
#define IS_NEWLINE_CHAR(_c) ([[NSCharacterSet newlineCharacterSet] characterIsMember:(_c)])

@interface CHCSVParser_Fast ()

- (unichar)_nextCharacter;
- (unichar)_peekNextCharacter;

@end

@implementation CHCSVParser_Fast

- (void)setDelimiter:(NSString *)d {
    [super setDelimiter:d];
    
    delimiter_character = [[self delimiter] characterAtIndex:0];
}

- (unichar)_nextCharacter {
    if (stringIndex >= [currentString length] / 2) {
        [self readNextChunk];
    }
    
    if (stringIndex >= [currentString length]) {
        return '\0';
    }
    
    return [currentString characterAtIndex:stringIndex++];
}

- (unichar)_peekNextCharacter {
    unichar next = [self _nextCharacter];
    if (next != '\0') {
        stringIndex--;
    }
    return next;
}

#pragma mark - Parsing

- (void)_parseLines {
    unichar peek = [self _peekNextCharacter];
    while (peek != '\0') {
        NSAutoreleasePool *p = [[NSAutoreleasePool alloc] init];
        
        [self _beginLine];
        [self _parseFields];
        [self _endLine];
        
        [p drain];
        
        peek = [self _peekNextCharacter];
    }
}

- (void)_parseFields {
    unichar next = [self _peekNextCharacter];
    
    while (!IS_NEWLINE_CHAR(next) && next != '\0') {
        next = [self _peekNextCharacter];
        if (next == '#') {
            [self _parseComment];
        } else {
            [self _parseField];
        }
        // this consumes the delimiter/newline
        next = [self _nextCharacter];
    }
}

- (void)_parseField {
    NSUInteger startIndex = stringIndex;
    unichar currentChar = [self _peekNextCharacter];
    
    BOOL balancedQuotes = YES;
    BOOL balancedEscapes = YES;
    
    if (currentChar == '"') {
        balancedQuotes = NO;
        (void)[self _nextCharacter]; // skip the quote
        currentChar = [self _peekNextCharacter];
    }
    
    while (currentChar != '\0') {
        if (balancedQuotes == YES && balancedEscapes == YES) {
            if (currentChar == delimiter_character) { break; }
            if (IS_NEWLINE_CHAR(currentChar)) { break; }
        }
        
        currentChar = [self _nextCharacter];
        
        if (currentChar == '"') {
            if (!balancedEscapes) {
                balancedEscapes = YES;
            } else {
                balancedQuotes = !balancedQuotes;
            }
        } else if (currentChar == '\\') {
            balancedEscapes = !balancedEscapes;
        } else {
            balancedEscapes = YES;
        }
        currentChar = [self _peekNextCharacter];
    }
    
    NSUInteger endIndex = stringIndex;
    NSRange fieldRange = NSMakeRange(startIndex, endIndex - startIndex);
    NSString *field = [currentString substringWithRange:fieldRange];
    [self _readField:field];
}

- (void)_parseComment {
    NSUInteger startIndex = stringIndex;
    unichar currentChar = '\0';
    
    // read up to the end of the line/file
    while ((currentChar = [self _peekNextCharacter]) && currentChar != '\0' && !IS_NEWLINE_CHAR(currentChar)) {
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
    
    for (NSUInteger i = 0; i < length; ++i) {
        unichar current = [rawField characterAtIndex:i];
        BOOL shouldAppend = YES;
        
        if (current == '"') {
            if (i == 0 || i+1 == length) {
                shouldAppend = NO;
                // this is the first/last character; skip it
            } else if (i+1 < length && [rawField characterAtIndex:i+1] == current) {
                // quote escaped by double-quoting
                i++; // skip the next quote
            }
        } else if (current == '\\') {
            if (i+1 < length) {
                i++;
                current = [rawField characterAtIndex:i];
            }
        }
        
        if (shouldAppend) {
            [field appendFormat:@"%C", current];
        }
    }
    return [field autorelease];
}

@end
