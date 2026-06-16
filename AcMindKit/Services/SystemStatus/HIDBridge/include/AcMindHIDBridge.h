#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDServiceClient *IOHIDServiceClientRef;
#ifdef __LP64__
typedef double IOHIDFloat;
#else
typedef float IOHIDFloat;
#endif

IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
CFArrayRef IOHIDEventSystemClientCopyServices(IOHIDEventSystemClientRef client);
IOHIDEventRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t field, int64_t options);
CFTypeRef IOHIDServiceClientCopyProperty(IOHIDServiceClientRef service, CFStringRef property);
IOHIDFloat IOHIDEventGetFloatValue(IOHIDEventRef event, int32_t field);

#define IOHIDEventFieldBase(type)   (type << 16)

NS_ASSUME_NONNULL_BEGIN

NSDictionary<NSString *, NSNumber *> *AcMindAppleSiliconSensors(int32_t page, int32_t usage, int32_t type);

NS_ASSUME_NONNULL_END
