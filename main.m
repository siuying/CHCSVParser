#import <Foundation/Foundation.h>
#import "CHCSV.h"
#import "CHCSVParser_Fast.h"

@interface Delegate : NSObject <CHCSVParserDelegate>
@end
@implementation Delegate

- (void) parser:(CHCSVParser *)parser didStartDocument:(NSString *)csvFile {
//    printf("<document>\n");
}
- (void) parser:(CHCSVParser *)parser didStartLine:(NSUInteger)lineNumber {
//    printf("\t<line num=\"%lu\">\n", lineNumber);
}
- (void) parser:(CHCSVParser *)parser didReadField:(NSString *)field {
//    printf("\t\t<field>%s</field>\n", [field UTF8String]);
}
- (void)parser:(CHCSVParser *)parser didReadComment:(NSString *)comment {
//    printf("\t\t<comment>%s</comment>\n", [comment UTF8String]);
}
- (void) parser:(CHCSVParser *)parser didEndLine:(NSUInteger)lineNumber {
//    printf("\t</line>\n");
}
- (void) parser:(CHCSVParser *)parser didEndDocument:(NSString *)csvFile {
//    printf("</document>\n");
}
- (void) parser:(CHCSVParser *)parser didFailWithError:(NSError *)error {
//	NSLog(@"ERROR: %@", error);
}
@end



int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString * file = @"/Users/dave/Developer/Open Source/Git Projects/CHCSVParser/Test.csv";
	Delegate * d = [[Delegate alloc] init];
    
    CHCSVParser *fast = [[CHCSVParser alloc] initWithContentsOfCSVFile:file encoding:NSUTF8StringEncoding error:nil];
    [fast setParserDelegate:d];
    
    NSTimeInterval s = [NSDate timeIntervalSinceReferenceDate];
    [fast parse];
    NSTimeInterval e = [NSDate timeIntervalSinceReferenceDate];
    
    [fast release];
    
    NSLog(@"diff: %f", e-s);
    
    file = @"/Users/dave/Developer/Open Source/Git Projects/CHCSVParser/giant-UTF16LE.csv";
    
    NSStringEncoding encoding = 0;
    CHCSVParser *p = [[CHCSVParser alloc] initWithContentsOfCSVFile:file usedEncoding:&encoding error:nil];
    [p setParserDelegate:d];
    
    s = [NSDate timeIntervalSinceReferenceDate];
    [p parse];
    e = [NSDate timeIntervalSinceReferenceDate];
    
    [p release];
    
    NSLog(@"diff: %f", e-s);
    
	/**
	CHCSVWriter *big = [[CHCSVWriter alloc] initWithCSVFile:file atomic:NO];
	for (int i = 0; i < 1000000; ++i) {
		NSAutoreleasePool *inner = [[NSAutoreleasePool alloc] init];
		for (int j = 0; j < 10; ++j) {
			[big writeField:[NSString stringWithFormat:@"%d-%d", i, j]];
		}
		[big writeLine];
		[inner drain];
	}
	[big closeFile];
	[big release];
	**/
	
	/**
	
	NSError * error = nil;
	NSArray * rows = [[NSArray alloc] initWithContentsOfCSVFile:file usedEncoding:&encoding delimiter:@"\t" error:&error];
	if ([rows count] == 0) {
		NSLog(@"error: %@", error);
		error = nil;
		rows = [NSArray arrayWithContentsOfCSVFile:file encoding:NSUTF8StringEncoding error:&error];
	}
	NSLog(@"error: %@", error);
	NSLog(@"%@", rows);
	
	CHCSVWriter *w = [[CHCSVWriter alloc] initWithCSVFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"test.tsv"] atomic:NO];
	[w setDelimiter:@"\t"];
	for (NSArray *row in rows) {
		[w writeLineWithFields:row];
	}
	[w closeFile];
	[w release];
    
	[rows release];
	 **/
	
	NSLog(@"Beginning...");
	encoding = 0;
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:file];
    NSError *error = nil;
	p = [[CHCSVParser alloc] initWithStream:stream usedEncoding:&encoding error:&error];
	
	NSLog(@"encoding: %@", CFStringGetNameOfEncoding(CFStringConvertNSStringEncodingToEncoding(encoding)));
	
	[p setParserDelegate:d];
	
	NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
	[p parse];
	NSTimeInterval end = [NSDate timeIntervalSinceReferenceDate];
	
	NSLog(@"raw difference: %f", (end-start));
	
	[d release];
    
    
    NSArray *a = [NSArray arrayWithContentsOfCSVFile:file encoding:encoding error:nil];
    NSLog(@"%@", a);
    NSString *str = [a CSVString];
    NSLog(@"%@", str);
    
	[p release];
	
	[pool drain];
    return 0;
}
