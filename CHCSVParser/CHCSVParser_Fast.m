//
//  CHCSVParser_Fast.m
//  CHCSVParser
//
//  Created by Dave DeLong on 9/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "CHCSVParser_Fast.h"

#define CHUNK_SIZE 1024

@interface CHCSVParser_Fast ()

- (void)_extractDataFromSource;
- (void)_extractStringFromBuffer;

- (unichar)_nextCharacter;
- (unichar)_peekNextCharacter;

@end

@implementation CHCSVParser_Fast

- (id)initWithCSVFile:(NSString *)file {
    self = [super init];
    if (self) {
        source = [[NSInputStream alloc] initWithFileAtPath:file];
        buffer = [[NSMutableData alloc] initWithCapacity:CHUNK_SIZE * 2];
        string = [[NSMutableString alloc] initWithCapacity:CHUNK_SIZE * 2];
        encoding = NSUTF8StringEncoding;
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
    uint8_t rawBuffer[CHUNK_SIZE];
    bzero(rawBuffer, CHUNK_SIZE * sizeof(uint8_t));
    
    NSInteger readAmount = [source read:rawBuffer maxLength:CHUNK_SIZE];
    
    if (readAmount > 0) {
        [buffer appendBytes:rawBuffer length:readAmount];
    }
}

- (void)_extractStringFromBuffer {
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

- (void)parse {
    [source open];
    
    unichar character = [self _nextCharacter];
    while (character != '\0') {
        NSLog(@"%x = '%C'", character, character);
        character = [self _nextCharacter];
    }
    
    [source close];
}

@end
