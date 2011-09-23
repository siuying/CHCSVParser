//
//  CHCSVParser.m
//  CHCSVParser
//
//  Created by Dave DeLong on 9/20/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "CHCSVParser.h"
#import "CHCSVParser_Internal.h"
#import "CHCSV.h"
#import "CHCSVTypes.h"
#import "CHCSVParser_Fast.h"
#import "CHCSVParser_Slow.h"

NSStringEncoding CHCSVOpenStreamAndSniffEncoding(NSInputStream *stream, uint8_t *bytes) {
    NSStringEncoding encoding = 0;
    [stream open];
    
    NSInteger bytesRead = [stream read:bytes maxLength:4];
    if (bytesRead == 4) {
		switch (bytes[0]) {
			case 0x00:
				if (bytes[1]==0x00 && bytes[2]==0xFE && bytes[3]==0xFF) {
					encoding = NSUTF32BigEndianStringEncoding;
				}
				break;
			case 0xEF:
				if (bytes[1]==0xBB && bytes[2]==0xBF) {
					encoding = NSUTF8StringEncoding;
				}
				break;
			case 0xFE:
				if (bytes[1]==0xFF) {
					encoding = NSUTF16BigEndianStringEncoding;
				}
				break;
			case 0xFF:
				if (bytes[1]==0xFE) {
					if (bytes[2]==0x00 && bytes[3]==0x00) {
						encoding = NSUTF32LittleEndianStringEncoding;
					} else {
						encoding = NSUTF16LittleEndianStringEncoding;
					}
				}
				break;
			default:
                NSLog(@"unable to determine encoding; assuming MacOSRoman");
                encoding = NSMacOSRomanStringEncoding;
				break;
		}
    }
    
    return encoding;
}

@interface CHCSVParser ()

@property (nonatomic, readonly) NSStringEncoding encoding;

@end

@implementation CHCSVParser
@synthesize hasStarted;
@synthesize parserDelegate;
@synthesize error;
@synthesize csvFile;
@synthesize delimiter;
@synthesize chunkSize;
@synthesize newlineCharacterSet;
@synthesize encoding;
@synthesize canceled;

- (id)_initWithStream:(NSInputStream *)readStream encoding:(NSStringEncoding)e initialData:(NSData *)initial error:(NSError **)anError {
    self = [super init];
    if (self) {
        input = [readStream retain];
        
        NSStreamStatus status = [input streamStatus];
        if (status != NSStreamStatusOpening &&
            status != NSStreamStatusOpen &&
            status != NSStreamStatusReading) {
            if (anError) {
                *anError = [NSError errorWithDomain:CHCSVErrorDomain code:CHCSVErrorCodeInvalidStream userInfo:[NSDictionary dictionaryWithObject:@"Unable to open file for reading" forKey:NSLocalizedDescriptionKey]];
            }
            [self release];
            return nil;
        }
		
        [self setHasStarted:NO];
        [self setNewlineCharacterSet:[NSCharacterSet newlineCharacterSet]];
		[self setDelimiter:@","];
        [self setChunkSize:8192];
        currentLine = 0;
        encoding = e;
        
        if ([initial length] > 0) {
            currentChunk = [[NSMutableData alloc] initWithData:initial];
        } else {
            currentChunk = [[NSMutableData alloc] initWithCapacity:[self chunkSize]];
        }
        currentString = [[NSMutableString alloc] init];
        
    }
    return self;
}

- (id)initWithStream:(NSInputStream *)readStream usedEncoding:(NSStringEncoding *)usedEncoding error:(NSError **)anError {
    NSStringEncoding finalEncoding = 0;
    NSData *initialData = nil;
    
    if (usedEncoding && *usedEncoding > 0) {
        finalEncoding = *usedEncoding;
        
        [readStream open];
    } else {
        uint8_t bytes[4];
        finalEncoding = CHCSVOpenStreamAndSniffEncoding(readStream, bytes);
        
        initialData = [NSData dataWithBytes:bytes length:4];
    }
    [self release];
    
    if (finalEncoding == NSUTF8StringEncoding || finalEncoding == NSMacOSRomanStringEncoding) {
        self = [[CHCSVParser_Fast alloc] _initWithStream:readStream encoding:finalEncoding initialData:initialData error:anError];
    } else {
        self = [[CHCSVParser_Slow alloc] _initWithStream:readStream encoding:finalEncoding initialData:initialData error:anError];
    }
    
    return self;
}

- (id)initWithStream:(NSInputStream *)readStream encoding:(NSStringEncoding)e error:(NSError **)anError {
    return [self initWithStream:readStream usedEncoding:&e error:anError];
}

- (id) initWithContentsOfCSVFile:(NSString *)aCSVFile encoding:(NSStringEncoding)e error:(NSError **)anError {
    return [self initWithContentsOfCSVFile:aCSVFile usedEncoding:&e error:anError];
}

- (id) initWithContentsOfCSVFile:(NSString *)aCSVFile usedEncoding:(NSStringEncoding *)usedEncoding error:(NSError **)anError {
    NSInputStream *readStream = [NSInputStream inputStreamWithFileAtPath:aCSVFile];
    
    self = [self initWithStream:readStream usedEncoding:usedEncoding error:anError];
	if (self) {
		csvFile = [aCSVFile copy];
	}
	return self;
}

- (id) initWithCSVString:(NSString *)csvString encoding:(NSStringEncoding)e error:(NSError **)anError {
    return [self initWithStream:[NSInputStream inputStreamWithData:[csvString dataUsingEncoding:encoding]]
                       encoding:e
                          error:anError];
}

- (void)dealloc {
    [currentString release];
    [currentChunk release];
    [csvFile release];
    [input close];
    [input release];
    [delimiter release];
    [error release];
    
    [super dealloc];
}

- (void)cancelParsing {
    canceled = YES;
}

- (void)extractStringFromCurrentChunk {
    
    NSUInteger readLength = [currentChunk length];
    do {
        NSString *readString = [[NSString alloc] initWithBytes:[currentChunk bytes] length:readLength encoding:encoding];
        if (readString == nil) {
            readLength--;
            if (readLength == 0) {
                error = [[NSError alloc] initWithDomain:CHCSVErrorDomain code:CHCSVErrorCodeInvalidStream userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                                    @"unable to interpret current chunk as a string", NSLocalizedDescriptionKey,
                                                                                                                    nil]];
                break;
            }
        } else {
            [currentString appendString:readString];
            [readString release];
            break;
        }
    } while (1);
    
    
    [currentChunk replaceBytesInRange:NSMakeRange(0, readLength) withBytes:NULL length:0];
}

- (void) readNextChunk {
    NSData *nextChunk = nil;
    uint8_t *bytes = calloc([self chunkSize], sizeof(uint8_t));
    @try {
        NSInteger bytesRead = [input read:bytes maxLength:[self chunkSize]];
        if (bytesRead >= 0) {
            nextChunk = [NSData dataWithBytes:bytes length:bytesRead];
        } else {
            //bytesRead < 0
            error = [[NSError alloc] initWithDomain:CHCSVErrorDomain 
                                               code:CHCSVErrorCodeInvalidStream 
                                           userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                     @"Unable to read from input stream", NSLocalizedDescriptionKey,
                                                     [input streamError], NSUnderlyingErrorKey,
                                                     nil]];
        }
    }
    @catch (NSException *e) {
        error = [[NSError alloc] initWithDomain:CHCSVErrorDomain code:CHCSVErrorCodeInvalidStream userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                            e, NSUnderlyingErrorKey,
                                                                                                            [e reason], NSLocalizedDescriptionKey,
                                                                                                            nil]];
        nextChunk = nil;
    }
    free(bytes);
    
    if ([nextChunk length] > 0) {
        // we were able to read something!
        [currentChunk appendData:nextChunk];
        
        [self extractStringFromCurrentChunk];
    }
}

- (void) setDelimiter:(NSString *)newDelimiter {
	if ([self hasStarted]) {
		[NSException raise:NSInvalidArgumentException format:@"You cannot set a delimiter after parsing has started"];
		return;
	}
	
	// the delimiter cannot be a newline character
    newDelimiter = [newDelimiter stringByTrimmingCharactersInSet:[self newlineCharacterSet]];
    
	BOOL shouldThrow = NO;
    if ([newDelimiter length] != 1) { shouldThrow = YES; }
	if ([newDelimiter isEqualToString:@"#"]) { shouldThrow = YES; }
	if ([newDelimiter isEqualToString:@"\""]) { shouldThrow = YES; }
	if ([newDelimiter isEqualToString:@"\\"]) { shouldThrow = YES; }
	
	if (shouldThrow) {
		[NSException raise:NSInvalidArgumentException format:@"%@ cannot be used as a delimiter", newDelimiter];
		return;
	}
	
	if (newDelimiter != delimiter) {
		[delimiter release];
		delimiter = [newDelimiter copy];
	}
}

#pragma mark -

- (void)parse {
    [self setHasStarted:YES];
    [self _beginDocument];
    
    [self _parseLines];
    
    [self _endDocument];
}

- (void)_beginDocument {
    if ([[self parserDelegate] respondsToSelector:@selector(parser:didStartDocument:)]) {
        [[self parserDelegate] parser:self didStartDocument:[self csvFile]];
    }
}

- (void)_endDocument {
    if ([self error] != nil) {
        if ([[self parserDelegate] respondsToSelector:@selector(parser:didFailWithError:)]) {
            [[self parserDelegate] parser:self didFailWithError:[self error]];
        }
    } else {
        if ([[self parserDelegate] respondsToSelector:@selector(parser:didEndDocument:)]) {
            [[self parserDelegate] parser:self didEndDocument:[self csvFile]];
        }
    }
}

- (void)_beginLine {
    currentLine++;
    if ([[self parserDelegate] respondsToSelector:@selector(parser:didStartLine:)]) {
        [[self parserDelegate] parser:self didStartLine:currentLine];
    }
}

- (void)_endLine {
    if ([[self parserDelegate] respondsToSelector:@selector(parser:didEndLine:)]) {
        [[self parserDelegate] parser:self didEndLine:currentLine];
    }
    
    [currentString replaceCharactersInRange:NSMakeRange(0, stringIndex) withString:@""];
    stringIndex = 0;
}


- (void)_parseLines { }
- (void)_parseFields { }
- (void)_parseField { }
- (void)_parseComment { }

- (NSString *)_fieldByCleaningField:(NSString *)rawField { return rawField; }

- (void)_readField:(NSString *)field {
    if ([[self parserDelegate] respondsToSelector:@selector(parser:didReadField:)]) {
        field = [self _fieldByCleaningField:field];
        [[self parserDelegate] parser:self didReadField:field];
    }
}

- (void)_readComment:(NSString *)comment {
    if ([[self parserDelegate] respondsToSelector:@selector(parser:didReadComment:)]) {
        [[self parserDelegate] parser:self didReadComment:comment];
    }
}

@end
