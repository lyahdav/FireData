#import <Foundation/Foundation.h>
#import <Firebase/Firebase.h>

@interface FirebaseMock : Firebase
- (void)simulateChange;
- (void)simulateChangeForKey:(NSString *)key;
@end