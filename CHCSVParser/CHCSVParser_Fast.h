//
//  CHCSVParser_Fast.h
//  CHCSVParser
//
//  Created by Dave DeLong on 9/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CHCSVParser_Fast : NSObject {
    NSInputStream *source;
    
    NSMutableData *buffer;
    NSStringEncoding encoding;
    
    NSMutableString *string;
    NSUInteger stringIndex;
}

- (id)initWithCSVFile:(NSString *)file;
- (void)parse;

@end
