#import "Kiwi.h"
#import "FireData.h"
#import "FirebaseMock.h"

@interface MockManagedObject : NSObject
@property (nonatomic, strong) NSString* firebaseData;
@property (nonatomic, strong) NSEntityDescription* entity;
- (NSDictionary *)firedata_propertiesDictionaryWithCoreDataKeyAttribute:(NSString *)coreDataKeyAttribute coreDataDataAttribute:(NSString *)coreDataDataAttribute;
@end
@implementation MockManagedObject
- (NSDictionary *)firedata_propertiesDictionaryWithCoreDataKeyAttribute:(NSString *)coreDataKeyAttribute coreDataDataAttribute:(NSString *)coreDataDataAttribute {
    return nil;
}
@end

SPEC_BEGIN(FireDataSpec)

    describe(@"FireData", ^{
        __block FireData *fireData;

        beforeEach(^{
            fireData = [FireData new];

            NSManagedObjectContext *mockContext = [self mockContext];
            [fireData setWriteManagedObjectContext:mockContext withCompletionBlock:nil];
        });

        it(@"observes the firebase node when linking to Core Data", ^{
            FirebaseMock *firebaseRoot = [FirebaseMock new];

            [[firebaseRoot should] receive:@selector(observeEventType:withBlock:) withArguments:theValue(FEventTypeChildAdded), any()];

            [fireData linkCoreDataEntity:@"Entity" withFirebase:firebaseRoot];
            [fireData startObserving];
        });

        it(@"observes the index when linking Core Data to nodes with indices", ^{
            FirebaseMock *firebaseRoot = [FirebaseMock new];
            FirebaseMock *indexFirebase = [FirebaseMock new];

            [[indexFirebase should] receive:@selector(observeEventType:withBlock:) withArguments:theValue(FEventTypeChildAdded), any()];

            [fireData linkCoreDataEntity:@"Entity" withFirebase:firebaseRoot withIndex:indexFirebase];
            [fireData startObserving];
        });

        it(@"fetches actual data when linking Core Data to nodes with indices", ^{
            FirebaseMock *firebaseRoot = [FirebaseMock new];
            FirebaseMock *indexFirebase = [FirebaseMock new];

            [fireData linkCoreDataEntity:@"Entity" withFirebase:firebaseRoot withIndex:indexFirebase];
            [fireData startObserving];

            FirebaseMock *entityValueNode = [FirebaseMock new];
            [firebaseRoot stub:@selector(childByAppendingPath:) andReturn:entityValueNode withArguments:@"1"];
            [[entityValueNode should] receive:@selector(observeEventType:withBlock:) withArguments:theValue(FEventTypeValue), any()];
            [indexFirebase simulateChange];
        });
        
        it(@"translates Firebase keys when getting changes from Firebase", ^{
            FirebaseMock *firebaseRoot = [FirebaseMock new];
            
            [fireData linkCoreDataEntity:@"Entity" withFirebase:firebaseRoot];
            NSManagedObjectContext *mockContext = [NSManagedObjectContext nullMock];
            [fireData observeManagedObjectContext:mockContext];
            [fireData startObserving];
            [NSEntityDescription stub:@selector(insertNewObjectForEntityForName:inManagedObjectContext:)];


            NSFetchRequest *mockFetchRequest = [NSFetchRequest new];
            [NSFetchRequest stub:@selector(fetchRequestWithEntityName:) andReturn:mockFetchRequest];
            [firebaseRoot simulateChangeForKey:@"foo_@@_bar"];
            [[[mockFetchRequest.predicate description] should] equal:@"firebaseKey == \"foo.bar\""];
        });
        
        it(@"translates Firebase keys when getting a new object from Firebase", ^{
            FirebaseMock *firebaseRoot = [FirebaseMock new];
            
            [fireData linkCoreDataEntity:@"Entity" withFirebase:firebaseRoot];
            NSManagedObjectContext *mockContext = [NSManagedObjectContext nullMock];
            [fireData observeManagedObjectContext:mockContext];
            [fireData startObserving];
            
            MockManagedObject *newManagedObject = [MockManagedObject nullMock];
            [[newManagedObject should] receive:@selector(setValue:forKey:) withArguments:@"foo.bar", @"firebaseKey"];
            [NSEntityDescription stub:@selector(insertNewObjectForEntityForName:inManagedObjectContext:) andReturn:newManagedObject];
            
            NSFetchRequest *mockFetchRequest = [NSFetchRequest new];
            [NSFetchRequest stub:@selector(fetchRequestWithEntityName:) andReturn:mockFetchRequest];
            [firebaseRoot simulateChangeForKey:@"foo_@@_bar"];
        });
    });
}

+ (NSManagedObjectContext *)mockContext {
    NSManagedObjectContext *mockContext = [NSManagedObjectContext nullMock];
    [mockContext stub:@selector(hasChanges) andReturn:theValue(YES)];
    [mockContext stub:@selector(performBlock:) withBlock:^id(NSArray *params) {
        void (^completionBlock)() = params[0];
        completionBlock();
        return nil;
    }];
    return mockContext;
}

@end
