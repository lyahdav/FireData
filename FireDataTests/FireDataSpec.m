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

        context(@"when linking a Core Data entity without an index", ^{
            __block FirebaseMock *firebaseRoot;
            __block NSManagedObjectContext *mockContext;

            beforeEach(^{
                firebaseRoot = [FirebaseMock new];
                [fireData linkCoreDataEntity:@"Entity" withFirebase:firebaseRoot];

                mockContext = [NSManagedObjectContext nullMock];
                [fireData observeManagedObjectContext:mockContext];
                [fireData startObserving];
            });

            it(@"writes to the Firebase node when saving a Core Data entity", ^{
                MockManagedObject *mockManagedObject = [self mockManagedObjectWithKeyAttribute:fireData.coreDataKeyAttribute];
                NSDictionary *userInfo = @{NSInsertedObjectsKey : [NSSet setWithObject:mockManagedObject]};

                FirebaseMock *childNode = [FirebaseMock new];
                [[childNode should] receive:@selector(updateChildValues:withCompletionBlock:) withArguments:@{@"key" : @"1"}, any()];
                [firebaseRoot stub:@selector(childByAppendingPath:) andReturn:childNode withArguments:@"1"];
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                                  userInfo:userInfo];
            });
            
            it(@"translates the Firebase key if needed", ^{
                MockManagedObject *mockManagedObject = [self mockManagedObjectWithKeyValue:@"foo.bar" forAttribute:fireData.coreDataKeyAttribute];
                NSDictionary *userInfo = @{NSInsertedObjectsKey : [NSSet setWithObject:mockManagedObject]};
                
                FirebaseMock *childNode = [FirebaseMock new];
                [[childNode should] receive:@selector(updateChildValues:withCompletionBlock:) withArguments:@{@"key" : @"foo.bar"}, any()];
                [firebaseRoot stub:@selector(childByAppendingPath:) andReturn:childNode withArguments:@"foo_@@_bar"];
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                                  userInfo:userInfo];
            });

            it(@"does not write managed objects that don't have a data attribute to Firebase", ^{
                NSManagedObject *mockManagedObject = [self mockManagedObjectWithoutDataAttributeWithKeyAttribute:fireData.coreDataKeyAttribute];

                FirebaseMock *childNode = [FirebaseMock new];
                [[childNode shouldNot] receive:@selector(setValue:withCompletionBlock:)];
                [firebaseRoot stub:@selector(childByAppendingPath:) andReturn:childNode withArguments:@"1"];

                NSDictionary *userInfo = @{NSInsertedObjectsKey : [NSSet setWithObject:mockManagedObject]};
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                                  userInfo:userInfo];
            });
        });

        context(@"when linking a Core Data entity with an index", ^{
            __block FirebaseMock *firebaseRoot;
            __block FirebaseMock *indexFirebase;
            __block NSManagedObjectContext *mockContext;
            __block NSDictionary *saveNotificationUserInfo;
            __block FirebaseMock *indexChildNode;
            __block MockManagedObject *mockManagedObject;

            beforeEach(^{
                firebaseRoot = [FirebaseMock new];
                indexFirebase = [FirebaseMock new];

                [fireData linkCoreDataEntity:@"Entity" withFirebase:firebaseRoot withIndex:indexFirebase];
                mockContext = [NSManagedObjectContext nullMock];
                [fireData observeManagedObjectContext:mockContext];
                [fireData startObserving];

                mockManagedObject = [self mockManagedObjectWithKeyAttribute:fireData.coreDataKeyAttribute];
                saveNotificationUserInfo = @{NSInsertedObjectsKey : [NSSet setWithObject:mockManagedObject]};

                indexChildNode = [FirebaseMock new];
                [indexFirebase stub:@selector(childByAppendingPath:) andReturn:indexChildNode withArguments:@"1"];
            });

            it(@"writes to the index in Firebase when saving a Core Data entity that is linked to an index", ^{
                [[indexChildNode should] receive:@selector(setValue:withCompletionBlock:) withArguments:@YES, any()];
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                                  userInfo:saveNotificationUserInfo];
            });

            it(@"writes the actual data in Firebase after writing to the index when saving a Core Data entity", ^{
                FirebaseMock *childNode = [FirebaseMock new];
                [[childNode should] receive:@selector(updateChildValues:withCompletionBlock:) withArguments:@{@"key" : @"1"}, any()];
                [firebaseRoot stub:@selector(childByAppendingPath:) andReturn:childNode withArguments:@"1"];
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                                  userInfo:saveNotificationUserInfo];
            });
            
            it(@"deletes the index of an entity if the entity is deleted", ^{
                Firebase *indexChild = [Firebase mock];
                [indexFirebase stub:@selector(childByAppendingPath:) andReturn:indexChild withArguments:@"1"];
                
                [[indexChild should] receive:@selector(removeValue)];
                
                NSDictionary *deletedUserInfo = @{NSDeletedObjectsKey : [NSSet setWithObject:mockManagedObject]};
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                                  userInfo:deletedUserInfo];
            });
            
            it(@"translates the Firebase key for the actual data when deleting an entity", ^{
                mockManagedObject = [self mockManagedObjectWithKeyValue:@"my.test.email@gmail.com" forAttribute:fireData.coreDataKeyAttribute];
                [[firebaseRoot should] receive:@selector(childByAppendingPath:) withArguments:@"my_@@_test_@@_email@gmail_@@_com"];
                [indexFirebase stub:@selector(childByAppendingPath:)];
                
                NSDictionary *deletedUserInfo = @{NSDeletedObjectsKey : [NSSet setWithObject:mockManagedObject]};
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                                  userInfo:deletedUserInfo];
            });
            
            it(@"translates the Firebase key for the index when deleting an entity", ^{
                mockManagedObject = [self mockManagedObjectWithKeyValue:@"my.test.email@gmail.com" forAttribute:fireData.coreDataKeyAttribute];
                [firebaseRoot stub:@selector(childByAppendingPath:)];
                [[indexFirebase should] receive:@selector(childByAppendingPath:) withArguments:@"my_@@_test_@@_email@gmail_@@_com"];
                
                NSDictionary *deletedUserInfo = @{NSDeletedObjectsKey : [NSSet setWithObject:mockManagedObject]};
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                                  userInfo:deletedUserInfo];
            });

            it(@"translates the Firebase key if needed when writing to the index", ^{
                [firebaseRoot stub:@selector(childByAppendingPath:)];
                [indexFirebase stub:@selector(childByAppendingPath:) andReturn:indexChildNode withArguments:@"my_@@_test_@@_email@gmail_@@_com"];

                mockManagedObject = [self mockManagedObjectWithKeyValue:@"my.test.email@gmail.com" forAttribute:fireData.coreDataKeyAttribute];
                NSDictionary *userInfo = @{NSInsertedObjectsKey : [NSSet setWithObject:mockManagedObject]};

                [[indexChildNode should] receive:@selector(setValue:withCompletionBlock:) withArguments:@YES, any()];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                                  userInfo:userInfo];
            });

            it(@"translates the Firebase key if needed when writing the actual data", ^{
                [indexFirebase stub:@selector(childByAppendingPath:)];

                mockManagedObject = [self mockManagedObjectWithKeyValue:@"my.test.email@gmail.com" forAttribute:fireData.coreDataKeyAttribute];
                NSDictionary *userInfo = @{NSInsertedObjectsKey : [NSSet setWithObject:mockManagedObject]};
                
                FirebaseMock *childNode = [FirebaseMock new];
                [[childNode should] receive:@selector(updateChildValues:withCompletionBlock:) withArguments:@{@"key" : @"my.test.email@gmail.com"}, any()];
                [firebaseRoot stub:@selector(childByAppendingPath:) andReturn:childNode withArguments:@"my_@@_test_@@_email@gmail_@@_com"];
                
                [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                                  userInfo:userInfo];
            });
            
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

+ (MockManagedObject *)mockManagedObjectWithKeyValue:(NSString *)keyValue forAttribute:(NSString *)coreDataKeyAttribute {
    MockManagedObject *mockManagedObject = [MockManagedObject new];
    [mockManagedObject stub:@selector(valueForKey:) andReturn:keyValue withArguments:coreDataKeyAttribute];
    NSEntityDescription *mockEntityDescription = [NSEntityDescription nullMock];
    [mockManagedObject stub:@selector(firebaseData) andReturn:@"Data"];
    [mockEntityDescription stub:@selector(name) andReturn:@"Entity"];
    [mockManagedObject stub:@selector(entity) andReturn:mockEntityDescription];
    [mockManagedObject stub:@selector(firedata_propertiesDictionaryWithCoreDataKeyAttribute:coreDataDataAttribute:)
                  andReturn:@{@"key" : keyValue}];
    return mockManagedObject;
}

+ (MockManagedObject *)mockManagedObjectWithKeyAttribute:(NSString *)coreDataKeyAttribute {
    return [self mockManagedObjectWithKeyValue:@"1" forAttribute:coreDataKeyAttribute];
}

+ (NSManagedObject *)mockManagedObjectWithoutDataAttributeWithKeyAttribute:(NSString *)coreDataKeyAttribute {
    NSManagedObject *mockManagedObject = [NSManagedObject nullMock];
    [mockManagedObject stub:@selector(valueForKey:) andReturn:@"1" withArguments:coreDataKeyAttribute];
    NSEntityDescription *mockEntityDescription = [NSEntityDescription nullMock];
    [mockEntityDescription stub:@selector(name) andReturn:@"Entity"];
    [mockManagedObject stub:@selector(entity) andReturn:mockEntityDescription];
    [mockManagedObject stub:@selector(firedata_propertiesDictionaryWithCoreDataKeyAttribute:coreDataDataAttribute:)
                  andReturn:@{@"key" : @"value"}];
    return mockManagedObject;
}

@end
