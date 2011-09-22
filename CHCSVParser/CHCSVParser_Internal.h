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

- (id)_initWithStream:(NSInputStream *)readStream encoding:(NSStringEncoding)encoding initialBytes:(uint8_t *)firstFour error:(NSError **)anError;;
- (void)readNextChunk;

@end