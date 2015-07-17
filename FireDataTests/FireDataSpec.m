#import "Kiwi.h"
#import "FireData.h"
#import "FirebaseMock.h"

SPEC_BEGIN(FireDataSpec)

    describe(@"FireData", ^{
        __block FireData *fireData;

        beforeEach(^{
            fireData = [FireData new];
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
        
        it(@"posts a notification when core data is updated from Firebase", ^{
            FirebaseMock *firebaseRoot = [FirebaseMock new];
            [fireData linkCoreDataEntity:@"Entity" withFirebase:firebaseRoot];
            [fireData startObserving];
            
            
            [[[NSNotificationCenter defaultCenter] should] receive:@selector(postNotificationName:object:) withArguments:FDCoreDataDidSaveNotification, nil];
            [NSEntityDescription stub:@selector(insertNewObjectForEntityForName:inManagedObjectContext:)];
            [firebaseRoot simulateChange];
        });

        it(@"writes to the Firebase node when saving a Core Data entity that is not linked to an index", ^{
            FirebaseMock *firebaseRoot = [FirebaseMock new];
            [fireData linkCoreDataEntity:@"Entity" withFirebase:firebaseRoot];

            NSManagedObjectContext *mockContext = [NSManagedObjectContext nullMock];
            [fireData observeManagedObjectContext:mockContext];
            [fireData startObserving];

            NSManagedObject *mockManagedObject = [self mockManagedObjectWithKeyAttribute:fireData.coreDataKeyAttribute];
            NSDictionary *userInfo = @{NSInsertedObjectsKey : [NSSet setWithObject:mockManagedObject]};

            FirebaseMock *childNode = [FirebaseMock new];
            [[childNode should] receive:@selector(setValue:withCompletionBlock:) withArguments:@{@"key" : @"value"}, any()];
            [firebaseRoot stub:@selector(childByAppendingPath:) andReturn:childNode withArguments:@"1"];
            [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:mockContext
                                                              userInfo:userInfo];
        });

        context(@"when linking a Core Data entity with an index", ^{
            __block FirebaseMock *firebaseRoot;
            __block FirebaseMock *indexFirebase;
            __block NSManagedObjectContext *mockContext;
            __block NSDictionary *saveNotificationUserInfo;
            __block FirebaseMock *indexChildNode;
            __block NSManagedObject *mockManagedObject;

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
                [[childNode should] receive:@selector(setValue:withCompletionBlock:) withArguments:@{@"key" : @"value"}, any()];
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
        });        

    });
}

+ (NSManagedObject *)mockManagedObjectWithKeyAttribute:(NSString *)coreDataKeyAttribute {
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
