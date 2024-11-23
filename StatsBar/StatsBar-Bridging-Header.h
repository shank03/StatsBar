//
//  StatsBar-Bridging-Header.h
//  StatsBar
//
//  Created by Shashank on 23/11/24.
//

#ifndef StatsBar_Bridging_Header_h
#define StatsBar_Bridging_Header_h

#include <CoreFoundation/CoreFoundation.h>

typedef struct IOReportSubscriptionRef* IOReportSubscriptionRef;

CFDictionaryRef IOReportCopyChannelsInGroup(CFStringRef a, CFStringRef b, uint64_t c, uint64_t d, uint64_t e);

void IOReportMergeChannels(CFDictionaryRef a, CFDictionaryRef b, CFTypeRef null);

IOReportSubscriptionRef IOReportCreateSubscription(void* a, CFMutableDictionaryRef b, CFMutableDictionaryRef* c, uint64_t d, CFTypeRef e);

#endif /* StatsBar_Bridging_Header_h */
