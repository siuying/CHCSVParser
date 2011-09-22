//
//  CHCSVParser_Fast.h
//  CHCSVParser
//
//  Created by Dave DeLong on 9/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CHCSVParserDelegate.h"
#import "CHCSVParser.h"

@interface CHCSVParser_Fast : CHCSVParser {
    NSInputStream *source;
    
    NSMutableData *buffer;
    
    NSMutableString *string;
    NSUInteger stringIndex;
    
    NSUInteger currentLine;
    unichar delimiter_character;
}

- (id)initWithStream:(NSInputStream *)readStream encoding:(NSStringEncoding)encoding initialBytes:(uint8_t *)firstFour error:(NSError **)anError;

- (id)initWithCSVFile:(NSString *)file;
- (id)initWithCSVString:(NSString *)csv;

- (void)parse;

@end
