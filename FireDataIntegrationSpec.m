#import "Kiwi.h"
#import "FireData.h"
#import "CoreDataManager.h"
#import "SomeEntity.h"
#import "SomeOtherEntity.h"

SPEC_BEGIN(FireDataIntegrationSpec)

describe(@"FireDataIntegration", ^{
    context(@"given I'm observing Firebase", ^{
        __block NSManagedObjectContext *managedObjectContext;
        __block CoreDataManager *manager;
        __block Firebase *firebaseRoot;

        beforeAll(^{
            __block BOOL clearedFirebase = NO;
            Firebase *fbRoot = [[Firebase alloc] initWithUrl:@"https://shining-fire-7516.firebaseio.com"];
            [fbRoot setValue:nil withCompletionBlock:^(NSError *error, Firebase *ref) {
                clearedFirebase = YES;
            }];
            
            [[expectFutureValue(theValue(clearedFirebase)) shouldEventuallyBeforeTimingOutAfter(10)] beTrue];
        });
        beforeEach(^{
            manager = [CoreDataManager new];
            managedObjectContext = manager.managedObjectContext;

            firebaseRoot = [[Firebase alloc] initWithUrl:@"https://shining-fire-7516.firebaseio.com"];

            FireData *fireData = [FireData new];
            [fireData linkCoreDataEntity:@"SomeEntity" withFirebase:[firebaseRoot childByAppendingPath:@"SomeEntities"] withIndex:[firebaseRoot childByAppendingPath:@"someEntitiesIndex"]];
            [fireData linkCoreDataEntity:@"SomeOtherEntity" withFirebase:[firebaseRoot childByAppendingPath:@"SomeOtherEntities"]];
            
            NSManagedObjectContext *writingContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [writingContext setParentContext:managedObjectContext];

            [fireData setWriteManagedObjectContext:writingContext withCompletionBlock:^(NSManagedObjectContext *innerContext) {
                NSError *error = nil;
                [innerContext save:&error];
                NSAssert(error == nil, @"error: %@", error);
            }];
            [fireData observeManagedObjectContext:managedObjectContext];
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
                return ((SomeOtherEntity *)[managedObjectContext objectWithID:otherEntity.objectID]).someEntity;
            };
            [[expectFutureValue(someEntityReferenceFromSomeOtherEntityInCoreData()) shouldEventuallyBeforeTimingOutAfter(10)] beNil];
        });
        
        it(@"Writes two objects to the server from a single save", ^{
            SomeEntity *entity1 = [NSEntityDescription insertNewObjectForEntityForName:@"SomeEntity" inManagedObjectContext:manager.managedObjectContext];
            SomeEntity *entity2 = [NSEntityDescription insertNewObjectForEntityForName:@"SomeEntity" inManagedObjectContext:manager.managedObjectContext];
            
            entity1.someAttribute = @"entity1";
            entity2.someAttribute = @"entity2";
            [manager saveContext];
            
            [self firebase:[firebaseRoot childByAppendingPath:@"SomeEntities"] entityKey:entity1.firebaseKey attributeShouldEqual:@"entity1"];
            [self firebase:[firebaseRoot childByAppendingPath:@"SomeEntities"] entityKey:entity2.firebaseKey attributeShouldEqual:@"entity2"];
        });
        
        it(@"converts an objects sync key to save properly in firebase", ^{
            SomeEntity *entity = [NSEntityDescription insertNewObjectForEntityForName:@"SomeEntity" inManagedObjectContext:manager.managedObjectContext];
            
            entity.someAttribute = @"entity1";
            entity.firebaseKey = @"this.key";
            [manager saveContext];
            
            [self firebase:[firebaseRoot childByAppendingPath:@"SomeEntities"] entityKey:[entity.firebaseKey stringByReplacingOccurrencesOfString:@"." withString:@"_@@_"] attributeShouldEqual:@"entity1"];
            __block id firebaseEntityAttribute = nil;
            [[firebaseRoot childByAppendingPath:@"someEntitiesIndex"] observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
                // snapshot.value is [NSNull null] if the node is empty
                if ([snapshot.value isKindOfClass:[NSDictionary class]]) {
                    firebaseEntityAttribute = snapshot.value[[entity.firebaseKey stringByReplacingOccurrencesOfString:@"." withString:@"_@@_"]];
                }
            }];
            [[expectFutureValue(firebaseEntityAttribute) shouldEventually] equal:@YES];
        });
        
        it(@"updates an object as well as the index when it is a linked entity", ^{
            SomeEntity *entity1 = [NSEntityDescription insertNewObjectForEntityForName:@"SomeEntity" inManagedObjectContext:manager.managedObjectContext];
            entity1.someAttribute = @"entity1";
            [manager saveContext];
            
            [self firebase:[firebaseRoot childByAppendingPath:@"SomeEntities"] entityKey:entity1.firebaseKey attributeShouldEqual:@"entity1"];
            
            __block id firebaseIndexValue = nil;
            [[firebaseRoot childByAppendingPath:@"someEntitiesIndex"] observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
                // snapshot.value is [NSNull null] if the node is empty
                if ([snapshot.value isKindOfClass:[NSDictionary class]]) {
                    firebaseIndexValue = snapshot.value[entity1.firebaseKey];
                }
            }];
            [[expectFutureValue(firebaseIndexValue) shouldEventually] equal:@YES];
            
            [managedObjectContext deleteObject:entity1];
            [manager saveContext];
            
            [self firebase:[firebaseRoot childByAppendingPath:@"SomeEntities"] entityKey:entity1.firebaseKey attributeShouldEqual:nil];
            [[firebaseRoot childByAppendingPath:@"someEntitiesIndex"] observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
                // snapshot.value is [NSNull null] if the node is empty
                if ([snapshot.value isKindOfClass:[NSDictionary class]]) {
                    firebaseIndexValue = snapshot.value[entity1.firebaseKey];
                }
            }];
            [[expectFutureValue(firebaseIndexValue) shouldEventually] beNil];
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
