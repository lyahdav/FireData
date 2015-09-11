#import "Kiwi.h"
#import "FireData.h"
#import "CoreDataManager.h"
#import "SomeEntity.h"

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
            [fireData linkCoreDataEntity:@"SomeEntity" withFirebase:firebaseRoot];
            [fireData observeManagedObjectContext:context];
            [fireData startObserving];
        });

        it(@"allows setting and clearing an attribute", ^{
            SomeEntity *entity = [self createAndSaveManagedObjectInManager:manager withAttribute:@"some value"];

            [self firebase:firebaseRoot entityKey:entity.firebaseKey attributeShouldEqual:@"some value"];

            entity.someAttribute = nil;
            [manager saveContext];

            [self firebase:firebaseRoot entityKey:entity.firebaseKey attributeShouldEqual:nil];
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
