//
//  CHCSVTypes.h
//  CHCSVParser
//
//  Created by Dave DeLong on 9/11/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
	CHCSVParserStateInsideFile = 0,
	CHCSVParserStateInsideLine = 1,
	CHCSVParserStateInsideField = 2,
	CHCSVParserStateInsideComment = 3,
    CHCSVParserStateCancelled = 4
} CHCSVParserState;

extern NSString *const CHCSVErrorDomain;
