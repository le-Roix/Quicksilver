//
//  QSDownloads.m
//  Quicksilver
//
//  Created by Rob McBroom on 4/8/11.
//
//  This class should be used to manage anything having to do with
//  the user's Downloads folder.
//

#import "QSDownloads.h"

@implementation QSDownloads
- (id)resolveProxyObject:(id)proxy {
    // Try and get the user's downloads folder setting (set in Safari)
    NSData *downloadsData = (NSData *)CFPreferencesCopyValue((CFStringRef) @"DownloadFolder", 
                                                                                          (CFStringRef) @"com.apple.internetconfigpriv", 
                                                                                          kCFPreferencesCurrentUser, 
                                                                                          kCFPreferencesAnyHost);
    NSString *downloads = nil;
    if (downloadsData) {
        downloads = [[NDAlias aliasWithData:downloadsData] quickPath];
        [downloadsData release];
    }
    
    // fall back to the default downloads folder if the user settings couldn't be resolved
    if (!downloads) {
        downloads = [[@"~/Downloads" stringByExpandingTildeInPath] stringByResolvingSymlinksInPath];
    }
    
	NSURL *downloadsURL = [NSURL URLWithString:downloads];
    
    if (!downloadsURL) {
        NSLog(@"Unable to locate downloads folder (path: %@)",downloads);
        NSBeep();
        return nil;
    }
    
    NSFileManager *manager = [NSFileManager defaultManager];
    
    NSError *err = nil;
    // An array of the directory contents, keeping the isDirectory key, attributeModificationDate key and skipping hidden files
	NSArray *contents = [manager contentsOfDirectoryAtURL:downloadsURL
							   includingPropertiesForKeys:[NSArray arrayWithObjects:NSURLIsDirectoryKey,NSURLAttributeModificationDateKey,nil]
												  options:NSDirectoryEnumerationSkipsHiddenFiles
													error:&err];
	if (err) {
		NSLog(@"Error resolving downloads path: %@", err);
		return nil;
	}

	NSString *downloadPath = nil;
	NSString *mrdpath = nil;
	NSDate *modified = nil;
    NSDate *mostRecent = [NSDate distantPast];

	NSNumber *isDir;
	NSNumber *isPackage;
	for (NSURL *downloadedFile in contents) {
		err = nil;
		NSString *fileExtension = [downloadedFile pathExtension];
		if ([fileExtension isEqualToString:@"download"] ||
			[fileExtension isEqualToString:@"part"] ||
			[fileExtension isEqualToString:@"dtapart"] ||
			[fileExtension isEqualToString:@"crdownload"]) {
			continue;
		}
		
		// Do not show folders
		if ([downloadedFile getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:&err] && [isDir boolValue]) {
			if (err != nil) {
				NSLog(@"Error getting resource value for %@\nError: %@",downloadPath,err);
				continue;
			}
			// Show packages (e.g. .app and .qsplugin packages)
			if ([downloadedFile getResourceValue:&isPackage forKey:NSURLIsPackageKey error:&err] && ![isPackage boolValue]) {
				if (err != nil) {
					NSLog(@"Error getting resource value for %@\nError: %@",downloadPath,err);
				}
				continue;
			}
		}
		downloadPath = [downloadedFile path];
		if([manager fileExistsAtPath:[downloadPath stringByAppendingPathExtension:@"part"]]) {
			continue;
		}
		// compare the modified date of the file with the most recent download file
		[downloadedFile getResourceValue:&modified forKey:NSURLAttributeModificationDateKey error:&err];
		if (err != nil) {
			NSLog(@"Error getting resource value for %@\nError: %@",downloadPath,err);
			continue;
		}
		if ([mostRecent compare:modified] == NSOrderedAscending) {
			mostRecent = modified;
			mrdpath = downloadPath;
		}
	}

    if (mrdpath) {
        return [QSObject fileObjectWithPath:mrdpath]; 
    }
    else {
        return nil;
    }
}
@end
