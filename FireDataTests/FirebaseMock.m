#import "Kiwi.h"
#import "FirebaseMock.h"

@interface FirebaseMock ()
@property (nonatomic, copy) void (^observeBlock)(FDataSnapshot *);
@end

@implementation FirebaseMock

- (FirebaseHandle)observeEventType:(FEventType)eventType withBlock:(void (^)(FDataSnapshot *snapshot))block {
    if (eventType == FEventTypeChildAdded) {
        self.observeBlock = block;
    }
    return 1;
}

- (void)simulateChange {
    if (self.observeBlock) {
        FDataSnapshot *snapshot = [FDataSnapshot nullMock];
        [snapshot stub:@selector(key) andReturn:@"1"];
        self.observeBlock(snapshot);
    }
}

- (void)setValue:(id)value withCompletionBlock:(void (^)(NSError *error, Firebase *ref))block {
    block(nil, nil);
}


@end