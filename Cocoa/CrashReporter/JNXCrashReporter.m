//
//  JNXCrashReporter.m
//  JollysFastVNC
//
//  Created by Patrick  Stein on 23.11.07.
//  Copyright 2007 jinx.de. All rights reserved.
//

#import "JNXCrashReporter.h"
#import "osversion.h"
#include <unistd.h>

#define JNX_CRASHREPORTER_DEFAULTS_DATEKEY		@"JNXCrashReporter.lastCrashTestDate"
#define JNX_CRASHREPORTER_DEFAULTS_VERSIONKEY	@"JNXCrashReporter.lastCrashVersion"
#define JNX_CRASHREPORTER_BODYTEXT				@"Please describe the circumstances leading to the crash and any other relevant information:\n\n\n\n\n\n\nCrashlog follows:\n"

@implementation JNXCrashReporter

+ (NSString *)logFileName
{
	#if !defined(NDEBUG) || (DEBUG >0)
		#warning not using Crashreporter in debug compiles 
		return nil;
	#endif
	return [[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:@"Logs"] stringByAppendingPathComponent:[[[NSProcessInfo processInfo] processName] stringByAppendingPathExtension:@"log"]];
}

+ (void)testForCrashWithBodyString:(NSString *)mailbodyString
{
	#if !defined(NDEBUG) || (DEBUG >0)
		#warning not using Crashreporter in debug compiles 
		return;
	#endif
	NSDate	*lastReportedDate;
	NSString *logfileName			= [self logFileName] ;
	NSString *previousLogfileName	= [logfileName stringByAppendingPathExtension:@"1"];

	[[NSFileManager defaultManager] removeFileAtPath:previousLogfileName handler:nil];
	if( ! [[NSFileManager defaultManager] movePath:logfileName toPath:previousLogfileName handler:nil] )
	{
		JLog(@"Could not move logfile %@ %@",logfileName,previousLogfileName);
	}
	
	int filenumber = open([logfileName fileSystemRepresentation],O_CREAT| O_APPEND|O_TRUNC| O_WRONLY, 0666);
	if( filenumber >= 0 )
	{
		close(STDERR_FILENO);
		dup2(filenumber, STDERR_FILENO);
		close(filenumber);
	}
	else
	{
		JLog(@"Could not open logfile %@",logfileName);
	}
	
	if( nil == mailbodyString )
	{
		mailbodyString	= JNX_CRASHREPORTER_BODYTEXT;
	}
	
	if(		(![[[NSBundle  mainBundle] infoDictionary] objectForKey: JNX_CRASHREPORTER_MAILTOKEY])
		||	(![[[NSBundle  mainBundle] infoDictionary] objectForKey: JNX_CRASHREPORTER_SUBJECTKEY]) )
	{
		JLog(@"did not find %@ or %@",JNX_CRASHREPORTER_MAILTOKEY,JNX_CRASHREPORTER_SUBJECTKEY);
		return;
	}
	
	if( ![[[[NSBundle  mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"] isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey: JNX_CRASHREPORTER_DEFAULTS_VERSIONKEY]] )
	{
		JLog(@"did not find correct version.");
		
		[[NSUserDefaults standardUserDefaults] setObject:[[[NSBundle  mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"] forKey: JNX_CRASHREPORTER_DEFAULTS_VERSIONKEY];
		[[NSUserDefaults standardUserDefaults] setObject: [NSDate date] forKey: JNX_CRASHREPORTER_DEFAULTS_DATEKEY];
		if( ! [[NSUserDefaults standardUserDefaults] synchronize] )
		{
			JLog(@"Could not synchronize defaults.");
		}
		return;
	}
	
	
	if( nil == (lastReportedDate = [[NSUserDefaults standardUserDefaults] objectForKey: JNX_CRASHREPORTER_DEFAULTS_DATEKEY]) )
	{
		lastReportedDate = [NSDate distantPast];
	}

  
	NSString	*lastCrashReportFilename = [self lastCrashReportFilename];
	NSDate		*lastCrashReportDate;
 	DJLog(@"%@",lastCrashReportFilename);
 
	if(		(nil != lastCrashReportFilename)
		&&	(nil != (lastCrashReportDate = [[[NSFileManager defaultManager] fileAttributesAtPath:[self lastCrashReportFilename] traverseLink: YES] fileModificationDate]) )
		&&  (NSOrderedAscending == [lastReportedDate compare: lastCrashReportDate]))
	{
		DJLog(@"has a new crashreport: %@ lastReportDate:%@ lastCrashReportDate:%@",lastCrashReportFilename,lastReportedDate,lastCrashReportDate);
		
		NSString *alertString = [NSString stringWithFormat:@"%@ has crashed the last time.\nTo improve %@ send the developer a mail.\n",[[NSProcessInfo processInfo] processName],[[NSProcessInfo processInfo] processName]];
		int alertreturn = [[NSAlert alertWithMessageText:@"Crashlog detected" defaultButton:@"Send Mail" alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:alertString] runModal];
				
		switch( alertreturn )
		{
			case NSAlertDefaultReturn	:
			{
				NSError *nsError = nil;
				NSString *mailString = [NSString stringWithFormat:@"mailto:%@?subject=%@ (%@ %@ %s %@)&body=%@\n%@\nLogfilecontents:\n%@\n",[[[NSBundle  mainBundle] infoDictionary] objectForKey: JNX_CRASHREPORTER_MAILTOKEY]
																											,[[[NSBundle  mainBundle] infoDictionary] objectForKey: JNX_CRASHREPORTER_SUBJECTKEY]
																											,[[[NSBundle  mainBundle] infoDictionary] objectForKey: @"CFBundleShortVersionString"]
																											,[[[NSBundle  mainBundle] infoDictionary] objectForKey: @"CFBundleVersion"]
																											,((CFByteOrderBigEndian==CFByteOrderGetCurrent())?"PPC":"i386")
																											,[[NSProcessInfo processInfo] operatingSystemVersionString]
																											,mailbodyString
																											,[NSString stringWithContentsOfFile:lastCrashReportFilename encoding:NSUTF8StringEncoding error:&nsError]
																											,[NSString stringWithContentsOfFile:previousLogfileName encoding:NSUTF8StringEncoding error:&nsError]];
													
				NSURL *url = [NSURL URLWithString:[(NSString*)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)mailString, NULL, NULL, kCFStringEncodingISOLatin1) autorelease]];
				[[NSWorkspace sharedWorkspace] openURL:url];
			};break;
		}
		[[NSUserDefaults standardUserDefaults] setObject: [NSDate date] forKey: JNX_CRASHREPORTER_DEFAULTS_DATEKEY];
	}
	if( ! [[NSUserDefaults standardUserDefaults] synchronize] )
	{
		JLog(@"Could not synchronize defaults.");
	}
}



+ (NSString*) lastCrashReportFilename
{
	DJLOG
	
	NSString				*crashlogFilename		= nil;
	NSDate					*crashlogDate			= [NSDate distantPast];
	
	NSString				*crashlogPathname				= [[NSHomeDirectory() stringByAppendingPathComponent: @"Library"] stringByAppendingPathComponent: @"Logs"];
	
	
	NSString				*logfileExtension	= @"crash";
	NSString				*logfilePrfix		= [NSString stringWithFormat:@"%@_",[[NSProcessInfo processInfo] processName]];
	
	if( 0x080000 == (0xFF0000&osversion()) )
	{
		crashlogPathname	= [crashlogPathname stringByAppendingPathComponent:@"CrashReporter"];
		logfileExtension	= @"log";
		logfilePrfix		= [NSString stringWithFormat:@"%@",[[NSProcessInfo processInfo] processName]];
	}
	
	NSDirectoryEnumerator	*crashLogDirectoryEnumerator	= [[NSFileManager defaultManager]  enumeratorAtPath:crashlogPathname];
	NSString				*intermediateCrashlogFilename;

	while( intermediateCrashlogFilename = [crashLogDirectoryEnumerator nextObject] )
	{
		if( ![[intermediateCrashlogFilename pathExtension] isEqualToString:logfileExtension] )
		{
			continue;
		}
	
		NSDictionary	*fileAttributes = [crashLogDirectoryEnumerator fileAttributes];

		if( NSFileTypeRegular == [[crashLogDirectoryEnumerator fileAttributes] objectForKey:NSFileType] )
		{
			NSString *currentFileName =  [intermediateCrashlogFilename lastPathComponent];
			DJLog(@"testing: %@",intermediateCrashlogFilename);
		
			if(		[currentFileName hasPrefix:logfilePrfix]
				&&	(NSOrderedAscending == [(NSDate *)crashlogDate compare:[fileAttributes objectForKey:NSFileModificationDate]] ) )
			{
				//DJLog(@"Found newer crashlog: %@",intermediateCrashlogFilename);
				
				crashlogFilename	= intermediateCrashlogFilename;
				crashlogDate		= [fileAttributes objectForKey:NSFileModificationDate];
			}
		}
	}
	if( ! crashlogFilename )
	{
		//DJLog(@"Did not find crashlog");
		return nil;
	}
	
	return [crashlogPathname stringByAppendingPathComponent:crashlogFilename];
}

@end


