//
//  Logging.h
//  Pods
//
//  Created by Grant Robinson on 11/7/16.
//
//

#ifndef GRFoundation_Logging_h
#define GRFoundation_Logging_h

#define LOG_LEVEL_DEF ddLogLevel
#define LOG_ASYNC_ENABLED YES

#import <CocoaLumberjack/CocoaLumberjack.h>

#ifdef PRODUCTION
static DDLogLevel ddLogLevel = DDLogLevelInfo;
#else
static DDLogLevel ddLogLevel = DDLogLevelInfo;
#endif


#endif /* GRFoundation_Logging_h */
