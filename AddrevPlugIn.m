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
        const NSRange selection = [tv selectedRange];
        const NSRange current_line_range = [tv rangeOfCurrentLine];
        NSString* target_str = nil;
        {
            NSRange target_range = NSMakeRange(selection.location, 0);
            // currently, previousWordRange gets not "word" str, so implement by hand
            {
                NSUInteger line_start_location = current_line_range.location;
                NSString* line_prev_str = [tv stringWithRange:NSMakeRange(line_start_location, selection.location - line_start_location)];
                NSError* error = nil;
                NSRegularExpression* regexp = [NSRegularExpression regularExpressionWithPattern:@"\\w+$" options:0 error:&error];
                NSTextCheckingResult* match = [regexp firstMatchInString:line_prev_str options:0 range:NSMakeRange(0, line_prev_str.length)];
                if (match) {
                    NSRange match_range = [match range];
                    target_range.location = selection.location - match_range.length;
                    target_range.length = match_range.length;
                }
            }
            {
                if (target_range.length > 0) {
                    target_str = [tv stringWithRange:target_range];
                }
                if (target_str == nil) {
                    return;
                }
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
            NSUInteger current_word_endlocation = selection.location;
            // currently, currentWordRange gets not "word" str, so implement by hand
            {
                NSUInteger line_end_location = current_line_range.location + current_line_range.length;
                NSString* line_next_str = [tv stringWithRange:NSMakeRange(selection.location, line_end_location - selection.location)];
                NSError* error = nil;
                NSRegularExpression* regexp = [NSRegularExpression regularExpressionWithPattern:@"^\\w+" options:0 error:&error];
                NSTextCheckingResult* match = [regexp firstMatchInString:line_next_str options:0 range:NSMakeRange(0, line_next_str.length)];
                if (match) {
                    current_word_endlocation = selection.location + [match range].length;
                }
            }
            
            // if current word end loc is larger than current loc, treat it as selected
            NSRange new_selection = selection;
            if (new_selection.location < current_word_endlocation) {
                new_selection.length = current_word_endlocation - new_selection.location;
            }
            
            NSUInteger current_index = NSNotFound;
            // if there is selection, find it from sorted_strs
            if (new_selection.length > 0) {
                NSString* selected_str = [tv stringWithRange:new_selection];
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
            [tv setSelectedRange:new_selection];
            [tv insertText:insert_str];
            [tv setSelectedRange:NSMakeRange(new_selection.location, insert_str.length)];
            [tv endUndoGrouping];
        }
    }
}

@end
