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
CFDictionaryRef IOReportCreateSamples(IOReportSubscriptionRef a, CFMutableDictionaryRef b, CFTypeRef c);
CFDictionaryRef IOReportCreateSamplesDelta(CFDictionaryRef a, CFDictionaryRef b, CFTypeRef c);
CFStringRef IOReportChannelGetGroup(CFDictionaryRef a);
CFStringRef IOReportChannelGetSubGroup(CFDictionaryRef a);
CFStringRef IOReportChannelGetChannelName(CFDictionaryRef a);
CFStringRef IOReportChannelGetUnitLabel(CFDictionaryRef a);
int32_t IOReportStateGetCount(CFDictionaryRef a);
CFStringRef IOReportStateGetNameForIndex(CFDictionaryRef a, int32_t b);
int64_t IOReportStateGetResidency(CFDictionaryRef a, int32_t b);
int64_t IOReportSimpleGetIntegerValue(CFDictionaryRef a, int32_t b);

#endif /* StatsBar_Bridging_Header_h */
