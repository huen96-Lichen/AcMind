#import "AcMindHIDBridge.h"
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

NSDictionary<NSString *, NSNumber *> *AcMindAppleSiliconSensors(int32_t page, int32_t usage, int32_t type) {
    NSDictionary *matching = @{
        @"PrimaryUsagePage": @(page),
        @"PrimaryUsage": @(usage)
    };

    IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
    if (system == NULL) {
        return nil;
    }

    IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)matching);
    CFArrayRef services = IOHIDEventSystemClientCopyServices(system);
    if (services == NULL) {
        CFRelease(system);
        return nil;
    }

    NSMutableDictionary<NSString *, NSNumber *> *result = [NSMutableDictionary dictionary];
    CFIndex count = CFArrayGetCount(services);
    for (CFIndex index = 0; index < count; index++) {
        IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, index);
        NSString *name = CFBridgingRelease(IOHIDServiceClientCopyProperty(service, CFSTR("Product")));
        IOHIDEventRef event = IOHIDServiceClientCopyEvent(service, type, 0, 0);
        if (name == nil || event == NULL) {
            if (event != NULL) {
                CFRelease(event);
            }
            continue;
        }

        double value = IOHIDEventGetFloatValue(event, IOHIDEventFieldBase(type));
        result[name] = @(value);
        CFRelease(event);
    }

    CFRelease(services);
    CFRelease(system);
    return result;
}
