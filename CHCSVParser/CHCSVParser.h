//
//  CHCSVParser.h
//  CHCSVParser
//
//  Created by Dave DeLong on 9/20/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CHCSVParserDelegate.h"

@interface CHCSVParser : NSObject {
    @protected
    BOOL hasStarted;
    NSInputStream *input;
    NSString *csvFile;
    NSString *delimiter;
    NSCharacterSet *newlineCharacterSet;
    NSError *error;
    NSStringEncoding encoding;
    BOOL canceled;
    NSUInteger chunkSize;
    NSMutableData *currentChunk;
    NSMutableString *currentString;
    NSUInteger currentLine;
    NSUInteger stringIndex;
    __weak id<CHCSVParserDelegate> parserDelegate;
}

@property (assign) __weak id<CHCSVParserDelegate> parserDelegate;
@property (readonly) NSError *error;
@property (nonatomic, readonly) NSString *csvFile;
@property (nonatomic, copy) NSString *delimiter;
@property (nonatomic, copy) NSCharacterSet *newlineCharacterSet;
@property (nonatomic) NSUInteger chunkSize;
@property (nonatomic, readonly, getter=isCanceled) BOOL canceled;

- (id) initWithStream:(NSInputStream *)readStream usedEncoding:(NSStringEncoding *)usedEncoding error:(NSError **)anError; //designated initializer
- (id) initWithStream:(NSInputStream *)readStream encoding:(NSStringEncoding)encoding error:(NSError **)anError;

- (id) initWithContentsOfCSVFile:(NSString *)aCSVFile encoding:(NSStringEncoding)encoding error:(NSError **)anError;
- (id) initWithContentsOfCSVFile:(NSString *)aCSVFile usedEncoding:(NSStringEncoding *)usedEncoding error:(NSError **)anError;

- (id) initWithCSVString:(NSString *)csvString encoding:(NSStringEncoding)encoding error:(NSError **)anError;

- (void) parse;
- (void) cancelParsing;

@end
