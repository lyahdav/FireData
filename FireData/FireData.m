//
//  FireData.m
//  FireData
//
//  Created by Jonathan Younger on 3/20/13.
//  Copyright (c) 2013 Overcommitted, LLC. All rights reserved.
//

#import "FireData.h"
#import "NSManagedObject+FireData.h"

typedef void (^fcdm_void_managedobjectcontext) (NSManagedObjectContext *context);
NSString *const FDCoreDataDidSaveNotification = @"FDCoreDataDidSaveNotification";

@interface FireData ()
@property (strong, nonatomic) NSManagedObjectContext *observedManagedObjectContext;
@property (strong, nonatomic) NSManagedObjectContext *writeManagedObjectContext;
@property (strong, nonatomic) NSMutableDictionary *linkedEntities;
@property (strong, nonatomic) NSMutableDictionary *indexEntities;
@property (copy, nonatomic) fcdm_void_managedobjectcontext writeManagedObjectContextCompletionBlock;
@end

@interface FireData (CoreData)
- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification;
- (void)managedObjectContextDidSave:(NSNotification *)notification;
- (NSString *)coreDataEntityForFirebase:(Firebase *)firebase;
- (BOOL)isCoreDataEntityLinked:(NSString *)entity;
- (NSManagedObject *)fetchCoreDataManagedObjectWithEntityName:(NSString *)entityName firebaseKey:(NSString *)firebaseKey;
@end

@interface FireData (Firebase)
- (Firebase *)firebaseForCoreDataEntity:(NSString *)entity;
- (void)observeFirebase:(Firebase *)firebase;
- (void)updateFirebase:(Firebase *)firebase withManagedObject:(NSManagedObject *)managedObject;
@end

@implementation FireData
- (void)dealloc
{
    [self stopObserving];
}

+ (NSString *)firebaseKey
{
    return [[NSUUID UUID] UUIDString];
}

- (id)init
{
    self = [super init];
    if (self) {
        _coreDataKeyAttribute = @"firebaseKey";
        _coreDataDataAttribute = @"firebaseData";
        _linkedEntities = [[NSMutableDictionary alloc] init];
        _indexEntities = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)observeManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    [self removeObserverForManagedObjectContext];
    self.observedManagedObjectContext = managedObjectContext;
}

- (void)removeObserverForManagedObjectContext
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    if (self.observedManagedObjectContext) {
        [notificationCenter removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:self.observedManagedObjectContext];
        [notificationCenter removeObserver:self name:NSManagedObjectContextDidSaveNotification object:self.observedManagedObjectContext];
    }

    self.observedManagedObjectContext = nil;
}

- (void)setWriteManagedObjectContext:(NSManagedObjectContext *)writeManagedObjectContext withCompletionBlock:(void (^)(NSManagedObjectContext *error))block
{
    self.writeManagedObjectContext = writeManagedObjectContext;
    self.writeManagedObjectContextCompletionBlock = [block copy];
}

- (void)linkCoreDataEntity:(NSString *)coreDataEntity withFirebase:(Firebase *)firebase
{
    self.linkedEntities[coreDataEntity] = firebase;
}

- (void)linkCoreDataEntity:(NSString *)coreDataEntity withFirebase:(Firebase *)firebase withIndex:(Firebase *)indexFirebase {
    self.linkedEntities[coreDataEntity] = firebase;
    self.indexEntities[coreDataEntity] = indexFirebase;
}

- (void)unlinkCoreDataEntity:(NSString *)coreDataEntity
{
    [self.linkedEntities[coreDataEntity] removeAllObservers];
    [self.linkedEntities removeObjectForKey:coreDataEntity];
}

- (void)startObserving
{
    [self.linkedEntities enumerateKeysAndObjectsUsingBlock:^(NSString *coreDataEntity, Firebase *firebase, BOOL *stop) {
        [self observeFirebase:firebase];
    }];

    if (self.observedManagedObjectContext) {
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(managedObjectContextObjectsDidChange:) name:NSManagedObjectContextObjectsDidChangeNotification object:self.observedManagedObjectContext];
        [notificationCenter addObserver:self selector:@selector(managedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:self.observedManagedObjectContext];
    }
}

- (void)stopObserving
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSArray *firebases = [self.linkedEntities allValues];
    [firebases makeObjectsPerformSelector:@selector(removeAllObservers)];
}

- (void)replaceFirebaseFromCoreData
{
    [self.linkedEntities enumerateKeysAndObjectsUsingBlock:^(NSString *coreDataEntity, Firebase *firebase, BOOL *stop) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:coreDataEntity];
        [fetchRequest setFetchBatchSize:25];
        NSError *error;
        NSArray *managedObjects = [self.observedManagedObjectContext executeFetchRequest:fetchRequest error:&error];
        NSAssert(!error, @"%@", error);
        for (NSManagedObject *managedObject in managedObjects) {
            [self updateFirebase:firebase withManagedObject:managedObject];
        };
    }];
}


@end

@implementation FireData (CoreData)
- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification
{
    NSMutableSet *managedObjects = [[NSMutableSet alloc] init];
    [managedObjects unionSet:[notification userInfo][NSInsertedObjectsKey]];
    [managedObjects unionSet:[notification userInfo][NSUpdatedObjectsKey]];

    for (NSManagedObject *managedObject in managedObjects) {
        if (![self isCoreDataEntityLinked:[[managedObject entity] name]]) return;

        if (![managedObject primitiveValueForKey:self.coreDataKeyAttribute]) {
            [managedObject setPrimitiveValue:[[self class] firebaseKey] forKey:self.coreDataKeyAttribute];
        }

        if (![managedObject changedValues][self.coreDataDataAttribute]) {
            [managedObject setPrimitiveValue:nil forKey:self.coreDataDataAttribute];
        }
    };
}

- (void)managedObjectContextDidSave:(NSNotification *)notification
{
    NSSet *deletedObjects = [notification userInfo][NSDeletedObjectsKey];
    for (NSManagedObject *managedObject in deletedObjects) {
        Firebase *firebase = [self firebaseForCoreDataEntity:[[managedObject entity] name]];
        Firebase *indexFirebase = self.indexEntities[[[managedObject entity] name]];

        if (firebase) {
            Firebase *child = [firebase childByAppendingPath:[managedObject valueForKey:self.coreDataKeyAttribute]];
            [child removeValue];
        }

        if (indexFirebase) {
            Firebase *indexChild = [indexFirebase childByAppendingPath:[managedObject valueForKey:self.coreDataKeyAttribute]];
            [indexChild removeValue];
        }
    };

    NSMutableSet *managedObjects = [[NSMutableSet alloc] init];
    [managedObjects unionSet:[notification userInfo][NSInsertedObjectsKey]];
    [managedObjects unionSet:[notification userInfo][NSUpdatedObjectsKey]];

    NSMutableSet *filteredObjects = [[NSMutableSet alloc] init];
    for (NSManagedObject *managedObject in managedObjects) {
        if ([managedObject respondsToSelector:NSSelectorFromString(self.coreDataDataAttribute)]) {
            [filteredObjects addObject:managedObject];
        }
    }
    NSSet *changedObjects = [filteredObjects filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"%K == nil", self.coreDataDataAttribute]];
    for (NSManagedObject *managedObject in changedObjects) {
        Firebase *firebase = [self firebaseForCoreDataEntity:[[managedObject entity] name]];
        if (firebase) {
            [self updateFirebase:firebase withManagedObject:managedObject];
        }
    };
}

- (NSString *)coreDataEntityForFirebase:(Firebase *)firebase
{
    return [[self.linkedEntities allKeysForObject:firebase] lastObject];
}

- (NSString *)coreDataEntityForFirebaseIndex:(Firebase *)firebase
{
    return [[self.indexEntities allKeysForObject:firebase] lastObject];
}

- (BOOL)isCoreDataEntityLinked:(NSString *)entity
{
    return [self firebaseForCoreDataEntity:entity] != nil;
}

- (NSManagedObject *)fetchCoreDataManagedObjectWithEntityName:(NSString *)entityName firebaseKey:(NSString *)firebaseKey
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"%K == %@", self.coreDataKeyAttribute, firebaseKey]];
    [fetchRequest setFetchLimit:1];
    NSError *error;
    NSManagedObject *managedObject = [[self.writeManagedObjectContext executeFetchRequest:fetchRequest error:&error] lastObject];
    NSAssert(!error, @"%@", error);
    return managedObject;
}

- (void)updateCoreDataEntity:(NSString *)entityName firebaseKey:(NSString *)firebaseKey properties:(NSDictionary *)properties
{
    if ((id)properties == [NSNull null]) return;

    NSManagedObject *managedObject = [self fetchCoreDataManagedObjectWithEntityName:entityName firebaseKey:firebaseKey];
    if (!managedObject) {
        managedObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.writeManagedObjectContext];
        [managedObject setValue:firebaseKey forKey:self.coreDataKeyAttribute];
    }

    [managedObject firedata_setPropertiesForKeysWithDictionary:properties coreDataKeyAttribute:self.coreDataKeyAttribute coreDataDataAttribute:self.coreDataDataAttribute];

    if ([self.writeManagedObjectContext hasChanges] && self.writeManagedObjectContextCompletionBlock) {
        self.writeManagedObjectContextCompletionBlock(self.writeManagedObjectContext);
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:FDCoreDataDidSaveNotification object:nil];
}
@end

@implementation FireData (Firebase)
- (Firebase *)firebaseForCoreDataEntity:(NSString *)entity
{
    return self.linkedEntities[entity];
}

- (void)observeFirebase:(Firebase *)firebase
{
    void (^updatedBlock)(FDataSnapshot *snapshot) = ^(FDataSnapshot *snapshot) {
        NSString *coreDataEntity = [self coreDataEntityForFirebase:firebase];
        if (!coreDataEntity) return;
        [self updateCoreDataEntity:coreDataEntity firebaseKey:snapshot.key properties:snapshot.value];
    };

    void (^indexUpdatedBlock)(FDataSnapshot *snapshot) = ^(FDataSnapshot *snapshot) {
        [[firebase childByAppendingPath:snapshot.key]
                observeEventType:FEventTypeValue
                       withBlock:^(FDataSnapshot *innerSnapshot) {
                           NSString *coreDataEntity = [self coreDataEntityForFirebase:firebase];
                           if (!coreDataEntity) return;
                           [self updateCoreDataEntity:coreDataEntity firebaseKey:innerSnapshot.key properties:innerSnapshot.value];
                       }];
    };

    NSString *coreDataEntity = [self coreDataEntityForFirebase:firebase];
    NSAssert(coreDataEntity != nil, @"expected mapping for firebase %@", firebase);
    Firebase *indexFirebase = self.indexEntities[coreDataEntity];
    if (indexFirebase == nil) {
        [self observeFirebase:firebase withBlock:updatedBlock];
    } else {
        [self observeFirebase:indexFirebase withBlock:indexUpdatedBlock];
    }
}

- (void)observeFirebase:(Firebase *)firebase withBlock:(void (^)(FDataSnapshot *))updatedBlock {
    [firebase observeEventType:FEventTypeChildAdded withBlock:updatedBlock];
    [firebase observeEventType:FEventTypeChildChanged withBlock:updatedBlock];

    void (^removedBlock)(FDataSnapshot *snapshot) = ^(FDataSnapshot *snapshot) {
        [self removeCoreDataEntityForSnapshot:snapshot firebase:firebase];
    };
    [firebase observeEventType:FEventTypeChildRemoved withBlock:removedBlock];
}

- (void)removeCoreDataEntityForSnapshot:(FDataSnapshot *)snapshot firebase:(Firebase *)firebase {
    NSString *coreDataEntity = [self coreDataEntityForFirebase:firebase] ?: [self coreDataEntityForFirebaseIndex:firebase];
    if (!coreDataEntity) {
        return;
    }

    NSManagedObject *managedObject = [self fetchCoreDataManagedObjectWithEntityName:coreDataEntity firebaseKey:snapshot.key];
    if (managedObject) {
        [self.writeManagedObjectContext deleteObject:managedObject];

        if (self.writeManagedObjectContextCompletionBlock) {
            self.writeManagedObjectContextCompletionBlock(self.writeManagedObjectContext);
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:FDCoreDataDidSaveNotification object:nil];
    }
}

- (void)updateFirebase:(Firebase *)firebase withManagedObject:(NSManagedObject *)managedObject
{
    Firebase *indexFirebase = self.indexEntities[[[managedObject entity] name]];
    NSDictionary *properties = [managedObject firedata_propertiesDictionaryWithCoreDataKeyAttribute:self.coreDataKeyAttribute coreDataDataAttribute:self.coreDataDataAttribute];

    if (indexFirebase == nil) {
        Firebase *child = [firebase childByAppendingPath:[managedObject valueForKey:self.coreDataKeyAttribute]];
        [child setValue:properties withCompletionBlock:^(NSError *error, Firebase *ref) {
            NSAssert(!error, @"%@", error);
        }];
    } else {
        Firebase *indexChild = [indexFirebase childByAppendingPath:[managedObject valueForKey:self.coreDataKeyAttribute]];
        [indexChild setValue:@YES withCompletionBlock:^(NSError *error, Firebase *ref) {
            NSAssert(!error, @"%@", error);
        }];

        Firebase *child = [firebase childByAppendingPath:[managedObject valueForKey:self.coreDataKeyAttribute]];
        [child setValue:properties withCompletionBlock:^(NSError *error, Firebase *ref) {
            NSAssert(!error, @"%@", error);
        }];
    }
}
@end
