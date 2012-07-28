#import "AddrevPlugIn.h"
#import "CodaPlugInsController.h"

@interface AddrevPlugIn ()

- (id)initWithController:(CodaPlugInsController*)inController;

@end


@implementation AddrevPlugIn

//2.0 and lower
- (id)initWithPlugInController:(CodaPlugInsController*)aController bundle:(NSBundle*)aBundle
{
    return [self initWithController:aController];
}

//2.0.1 and higher
- (id)initWithPlugInController:(CodaPlugInsController*)aController plugInBundle:(NSObject <CodaPlugInBundle> *)plugInBundle
{
    return [self initWithController:aController];
}

- (id)initWithController:(CodaPlugInsController*)inController
{
	if ( (self = [super init]) != nil ) {
		controller = inController;
		[controller registerActionWithTitle:NSLocalizedString(@"AddrevNext", @"AddrevNext") target:self selector:@selector(addrev_next:)];
		[controller registerActionWithTitle:NSLocalizedString(@"AddrevPrev", @"AddrevPrev") target:self selector:@selector(addrev_prev:)];
	}
    
	return self;
}

- (NSString*)name
{
	return @"Addrev";
}

- (void)addrev_next:(id)sender
{
    [self addrev:sender isDirectionNext:YES];
}

- (void)addrev_prev:(id)sender
{
    [self addrev:sender isDirectionNext:NO];
}

- (void)addrev:(id)sender isDirectionNext:(BOOL)is_next
{
	CodaTextView* tv = [controller focusedTextView:self];
	if ( tv ) {
        //==== get addrev target
        NSString* target_str = nil;
        NSRange target_range = [tv previousWordRange];
        {
            if (target_range.length > 0) {
                target_str = [tv stringWithRange:target_range];
            }
            if (target_str == nil) {
                return;
            }
        }
        
        //==== find addrev strs
        NSArray* sorted_strs = nil;
        {
            NSString* tv_str = [tv string];
            NSString* find_pattern = [NSString stringWithFormat:@"\\b%@(\\w+)", target_str];
            
            NSError* error = nil;
            NSRegularExpression* regexp = [NSRegularExpression regularExpressionWithPattern:find_pattern options:0 error:&error];
            NSMutableSet* strs = [NSMutableSet setWithCapacity:10];
            
            NSRegularExpressionOptions options = 0;
            NSRange range = NSMakeRange(0, tv_str.length);
            id block = ^(NSTextCheckingResult *match, NSMatchingFlags flag, BOOL *stop) {
                [strs addObject:[tv_str substringWithRange:[match rangeAtIndex:1]]];
            };
            [regexp enumerateMatchesInString:tv_str options:options range:range usingBlock:block];
            if ([strs count] > 0) {
                sorted_strs = [[strs allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
            }
            if (sorted_strs == nil) {
                return;
            }
        }
        
        //==== choose next or prev word and replace selected range
        {
            NSRange current_word_range = [tv currentWordRange];
            NSRange selection = [tv selectedRange];
            NSUInteger current_word_endlocation = current_word_range.location + current_word_range.length;
            
            // if current word end loc is larger than current loc, treat it as selected
            if (selection.location < current_word_endlocation) {
                selection.length = current_word_endlocation - selection.location;
            }
            
            NSUInteger current_index = NSNotFound;
            // if there is selection, find it from sorted_strs
            if (selection.length > 0) {
                NSString* selected_str = [tv stringWithRange:selection];
                current_index = [sorted_strs indexOfObject:selected_str inSortedRange:NSMakeRange(0, sorted_strs.count) options:0 usingComparator:^(id lhs, id rhs) {return [lhs caseInsensitiveCompare:rhs];}];
            }
            
            // choose target index
            NSUInteger insert_str_index = 0;
            if (current_index == NSNotFound) {
                if (is_next) {
                    insert_str_index = 0;
                } else {
                    insert_str_index = sorted_strs.count - 1;
                }
            } else {
                if (is_next) {
                    insert_str_index = current_index + 1;
                    if (insert_str_index >= sorted_strs.count) {
                        insert_str_index = 0;
                    }
                } else {
                    if (current_index == 0) {
                        insert_str_index = sorted_strs.count - 1;
                    } else {
                        insert_str_index = current_index - 1;
                    }
                }
            }
            
            // insert addrev str and select it
            NSString* insert_str = [sorted_strs objectAtIndex:insert_str_index];
            [tv beginUndoGrouping];
            [tv setSelectedRange:selection];
            [tv insertText:insert_str];
            [tv setSelectedRange:NSMakeRange(selection.location, insert_str.length)];
            [tv endUndoGrouping];
        }
    }
}

@end
