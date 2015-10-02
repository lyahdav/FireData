#import "Kiwi.h"
#import "FireData.h"
#import "CoreDataManager.h"
#import "SomeEntity.h"
#import "SomeOtherEntity.h"

SPEC_BEGIN(FireDataIntegrationSpec)

describe(@"FireDataIntegration", ^{
    context(@"given I'm observing Firebase", ^{
        __block NSManagedObjectContext *context;
        __block CoreDataManager *manager;
        __block Firebase *firebaseRoot;

        beforeEach(^{
            manager = [CoreDataManager new];
            context = manager.managedObjectContext;

            firebaseRoot = [[Firebase alloc] initWithUrl:@"https://shining-fire-7516.firebaseio.com"];

            FireData *fireData = [FireData new];
            [fireData linkCoreDataEntity:@"SomeEntity" withFirebase:[firebaseRoot childByAppendingPath:@"SomeEntities"]];
            [fireData linkCoreDataEntity:@"SomeOtherEntity" withFirebase:[firebaseRoot childByAppendingPath:@"SomeOtherEntities"]];
            
            NSManagedObjectContext *writingContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [writingContext setParentContext:context];

            [fireData setWriteManagedObjectContext:writingContext withCompletionBlock:^(NSManagedObjectContext *innerContext) {
                NSError *error = nil;
                [innerContext save:&error];
                NSAssert(error == nil, @"error: %@", error);
            }];
            [fireData observeManagedObjectContext:context];
            [fireData startObserving];
        });

        it(@"allows setting and clearing an attribute", ^{
            SomeEntity *entity = [self createAndSaveManagedObjectInManager:manager withAttribute:@"some value"];

            [self firebase:[firebaseRoot childByAppendingPath:@"SomeEntities"] entityKey:entity.firebaseKey attributeShouldEqual:@"some value"];

            entity.someAttribute = nil;
            [manager saveContext];

            [self firebase:[firebaseRoot childByAppendingPath:@"SomeEntities"] entityKey:entity.firebaseKey attributeShouldEqual:nil];
        });
        
        it(@"Removes one to many relationships in core data when removed from firebase", ^{
            SomeEntity *entity = [NSEntityDescription insertNewObjectForEntityForName:@"SomeEntity" inManagedObjectContext:manager.managedObjectContext];
            SomeOtherEntity *otherEntity = [NSEntityDescription insertNewObjectForEntityForName:@"SomeOtherEntity" inManagedObjectContext:manager.managedObjectContext];
            otherEntity.someEntity = entity;
            otherEntity.name = @"test";
            [manager saveContext];
            
            Firebase *someEntityReferenceFromSomeOtherEntityInFirebase = [[[firebaseRoot childByAppendingPath:@"SomeOtherEntities"] childByAppendingPath:otherEntity.firebaseKey] childByAppendingPath:@"someEntity"];
            
            __block NSString *someEntityReference = nil;
            [someEntityReferenceFromSomeOtherEntityInFirebase observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
                someEntityReference = snapshot.value;
            }];

            [[expectFutureValue(someEntityReference) shouldEventually] equal:entity.firebaseKey];
            
            [someEntityReferenceFromSomeOtherEntityInFirebase setValue:nil];
            
            id(^someEntityReferenceFromSomeOtherEntityInCoreData)() = ^id(){
                return ((SomeOtherEntity *)[context objectWithID:otherEntity.objectID]).someEntity;
            };
            [[expectFutureValue(someEntityReferenceFromSomeOtherEntityInCoreData()) shouldEventuallyBeforeTimingOutAfter(10)] beNil];
        });
    });
});

}

+ (SomeEntity *)createAndSaveManagedObjectInManager:(CoreDataManager *)manager withAttribute:(NSString *)attributeValue {
    SomeEntity *entity = [NSEntityDescription insertNewObjectForEntityForName:@"SomeEntity" inManagedObjectContext:manager.managedObjectContext];
    entity.someAttribute = attributeValue;
    [manager saveContext];
    return entity;
}

+ (void)firebase:(Firebase *)firebase entityKey:(NSString *)entityKey attributeShouldEqual:(NSString *)expectedAttributeValue {
    id someNonNilValue = @555; // we need this because when using shouldEventually with nil we want to make sure we the variable is not nil initially
    __block id firebaseEntityAttribute = someNonNilValue;
    [firebase observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        // snapshot.value is [NSNull null] if the node is empty
        if ([snapshot.value isKindOfClass:[NSDictionary class]]) {
            firebaseEntityAttribute = snapshot.value[entityKey][@"someAttribute"];
        } else {
            firebaseEntityAttribute = nil;
        }
    }];
    if (expectedAttributeValue == nil) {
        [[expectFutureValue(firebaseEntityAttribute) shouldEventually] beNil];
    } else {
        [[expectFutureValue(firebaseEntityAttribute) shouldEventually] equal:expectedAttributeValue];
    }
}

@end
