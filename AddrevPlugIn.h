#import <Cocoa/Cocoa.h>
#import "CodaPluginsController.h"

@class CodaPlugInsController;

@interface AddrevPlugIn : NSObject <CodaPlugIn>
{
	CodaPlugInsController* controller;
}

@end
