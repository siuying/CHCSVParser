//
//  CHCSVParser_Internal.h
//  CHCSVParser
//
//  Created by Dave DeLong on 9/21/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CHCSVParser.h"

@interface CHCSVParser ()

@property (nonatomic) BOOL hasStarted;

- (id)_initWithStream:(NSInputStream *)readStream encoding:(NSStringEncoding)encoding initialData:(NSData *)initial error:(NSError **)anError;
- (void)readNextChunk;

- (void)_beginDocument;
- (void)_endDocument;

- (void)_parseLines;
- (void)_beginLine;
- (void)_endLine;

- (void)_parseFields;
- (void)_parseField;
- (void)_parseComment;

- (NSString *)_fieldByCleaningField:(NSString *)rawField;
- (void)_readField:(NSString *)rawField;
- (void)_readComment:(NSString *)rawComment;

@end