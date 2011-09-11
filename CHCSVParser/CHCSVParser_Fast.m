//
//  CHCSVParser_Fast.m
//  CHCSVParser
//
//  Created by Dave DeLong on 9/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "CHCSVParser_Fast.h"
#import "CHCSVTypes.h"

#define CHUNK_SIZE 1024
#define IS_NEWLINE_CHAR(_c) ([[NSCharacterSet newlineCharacterSet] characterIsMember:(_c)])

@interface CHCSVParser_Fast ()

- (void)_extractDataFromSource;
- (void)_extractStringFromBuffer;

- (unichar)_nextCharacter;
- (unichar)_peekNextCharacter;

@property (nonatomic, assign) CHCSVParserState state;

- (void)_beginDocument;
- (void)_endDocument;

- (void)_parseLines;
- (void)_beginLine;
- (void)_endLine;

- (void)_parseFields;
- (void)_parseField;
- (void)_parseComment;

- (void)_readField:(NSString *)rawField;
- (void)_readComment:(NSString *)rawComment;

@end

@implementation CHCSVParser_Fast

@synthesize state=_state;

- (id)initWithCSVFile:(NSString *)file {
    self = [super init];
    if (self) {
        source = [[NSInputStream alloc] initWithFileAtPath:file];
        buffer = [[NSMutableData alloc] initWithCapacity:CHUNK_SIZE * 2];
        string = [[NSMutableString alloc] initWithCapacity:CHUNK_SIZE * 2];
        encoding = NSUTF8StringEncoding;
        delimiter = ',';
    }
    return self;
}

- (id)initWithCSVString:(NSString *)csv {
    self = [super init];
    if (self) {
        source = nil;
        buffer = nil;
        
        string = [csv mutableCopy];
        encoding = [string fastestEncoding];
        delimiter = ',';
    }
    return self;
}

- (void)dealloc {
    [source release];
    [buffer release];
    [string release];
    [super dealloc];
}

- (void)_extractDataFromSource {
    if (source == nil) { return; }
    
    uint8_t rawBuffer[CHUNK_SIZE];
    bzero(rawBuffer, CHUNK_SIZE * sizeof(uint8_t));
    
    NSInteger readAmount = [source read:rawBuffer maxLength:CHUNK_SIZE];
    
    if (readAmount > 0) {
        [buffer appendBytes:rawBuffer length:readAmount];
    }
}

- (void)_extractStringFromBuffer {
    if (buffer == nil) { return; }
    
    if ([buffer length] < CHUNK_SIZE) {
        [self _extractDataFromSource];
    }
    
    NSString *extracted = nil;
    NSRange dataRange = NSMakeRange(0, [buffer length]);
    
    while (dataRange.length > 0) {
        NSData *data = [buffer subdataWithRange:dataRange];
        extracted = [[NSString alloc] initWithData:data encoding:encoding];
        
        if (extracted != nil) {
            [buffer replaceBytesInRange:dataRange withBytes:NULL length:0];
            [string appendString:extracted];
            [extracted release];
            
            break;
        } else {
            dataRange.length = dataRange.length - 1;
        }
    }
}

- (unichar)_nextCharacter {
    if (_state == CHCSVParserStateCancelled) { return '\0'; }
    
    if (stringIndex >= [string length] / 2) {
        [self _extractStringFromBuffer];
    }
    
    if (stringIndex >= [string length]) {
        return '\0';
    }
    
    return [string characterAtIndex:stringIndex++];
}

- (unichar)_peekNextCharacter {
    unichar next = [self _nextCharacter];
    if (next != '\0') {
        stringIndex--;
    }
    return next;
}

#pragma mark - Parsing

- (void)setState:(CHCSVParserState)state {
    if (state != _state && _state != CHCSVParserStateCancelled) {
        _state = state;
    }
}

- (void)parse {
    [source open];
    [self _beginDocument];
    
    [self _parseLines];
    
    [self _endDocument];
    [source close];
}

- (void)_parseLines {
    unichar peek = [self _peekNextCharacter];
    while (peek != '\0') {
        [self _beginLine];
        [self _parseFields];
        [self _endLine];
        currentLine++;
        peek = [self _peekNextCharacter];
    }
}

- (void)_parseFields {
    unichar peek = [self _peekNextCharacter];
    
    while (!IS_NEWLINE_CHAR(peek)) {
        if (peek == '#') {
            [self _parseComment];
        } else {
            [self _parseField];
        }
        peek = [self _peekNextCharacter];
    }
    
    if (IS_NEWLINE_CHAR(peek)) {
        //consume the newline
        (void)[self _nextCharacter];
    }
}

- (void)_parseField {
    NSUInteger startIndex = stringIndex;
    unichar currentChar = [self _nextCharacter];
    
    BOOL balancedQuotes = YES;
    BOOL balancedEscapes = YES;
    
    if (currentChar == '"') {
        balancedQuotes = NO;
        currentChar = [self _nextCharacter]; // skip the quote
    }
    
    while (currentChar != '\0' && (balancedQuotes == NO || balancedEscapes == NO || currentChar != delimiter || !IS_NEWLINE_CHAR(currentChar))) {
        if (currentChar == '"') {
            if (!balancedEscapes) {
                balancedEscapes = YES;
            } else {
                balancedQuotes = !balancedQuotes;
            }
        } else if (currentChar == '\\') {
            balancedEscapes = !balancedEscapes;
        }
        currentChar = [self _nextCharacter];
    }
    
    NSUInteger endIndex = stringIndex;
    if (currentChar == delimiter || IS_NEWLINE_CHAR(currentChar)) {
        endIndex--;
    }
    NSRange fieldRange = NSMakeRange(startIndex, endIndex - startIndex);
    NSString *field = [string substringWithRange:fieldRange];
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
    NSString *comment = [string substringWithRange:commentRange];
    [self _readComment:comment];
}

#pragma mark - Delegate Callbacks

// make sure these each check for the cancelled state

- (void)_beginDocument {
    printf("<document>\n");
}

- (void)_endDocument {
    printf("</document>\n");
}

- (void)_beginLine {
    printf("\t<line %lu>\n", currentLine);
}

- (void)_endLine {
    printf("\t</line>\n");
}

- (void)_readField:(NSString *)rawField {
    printf("\t\t<field>%s</field>\n", [rawField UTF8String]);
}

- (void)_readComment:(NSString *)rawComment {
    printf("\t\t<comment>%s</comment>\n", [rawComment UTF8String]);
}

@end
