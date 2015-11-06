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

@interface FireData ()
@property (strong, nonatomic) NSManagedObjectContext *observedManagedObjectContext;
@property (strong, nonatomic) NSManagedObjectContext *writeManagedObjectContext;
@property (strong, nonatomic) NSMutableDictionary *linkedEntities;
@property (strong, nonatomic) NSMutableDictionary *indexEntities;
@property (copy, nonatomic) fcdm_void_managedobjectcontext writeManagedObjectContextCompletionBlock;

- (void)managedObjectContextObjectsDidChange:(NSNotification *)notification;
- (void)managedObjectContextDidSave:(NSNotification *)notification;
- (NSString *)coreDataEntityForFirebase:(Firebase *)firebase;
- (BOOL)isCoreDataEntityLinked:(NSString *)entity;
- (NSManagedObject *)fetchCoreDataManagedObjectWithEntityName:(NSString *)entityName firebaseKey:(NSString *)firebaseKey;
- (Firebase *)firebaseForCoreDataEntity:(NSString *)entity;
- (void)observeFirebase:(Firebase *)firebase;
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
    [self.indexEntities[coreDataEntity] removeAllObservers];
    [self.indexEntities removeObjectForKey:coreDataEntity];
}

- (void)unlinkAllCoreDataEntities {
    for (NSString *entityName in [[self.linkedEntities allKeys] copy]) {
        [self unlinkCoreDataEntity:entityName];
    }
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

- (void)uploadMissingCoreDataObjectsToFirebase:(FDataSnapshot *)snapshot
{
    NSMutableDictionary *firebaseUpdateDictionary = [NSMutableDictionary new];
    [self enumerateLinkedEntitiesUsingBlock:^(NSArray *managedObjects, Firebase *firebase) {
        for (NSManagedObject *managedObject in managedObjects) {
            NSString *syncID = [self firebaseSyncValueForManagedObject:managedObject];
            NSString *entityName = [[NSURL URLWithString:firebase.description] lastPathComponent];
            NSString *childPath = [NSString stringWithFormat:@"%@/%@", entityName, syncID];

            if (![snapshot hasChild:childPath]) {
                [self updateFirebaseDictionary:firebaseUpdateDictionary forManagedObject:managedObject withFirebaseNode:firebase];
            }
        };
    }];
    if (firebaseUpdateDictionary.count > 0) {
        [self updateFirebaseRootWithDictionary:firebaseUpdateDictionary];
    }
}

- (void)addMissingFirebaseKeyToCoreDataObjects
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K == nil", self.coreDataKeyAttribute];

    [self enumerateLinkedEntitiesWithPredicate:predicate usingBlock:^(NSArray *managedObjects, Firebase *firebase) {
        for (NSManagedObject *managedObject in managedObjects) {
            if ([managedObject valueForKey:self.coreDataKeyAttribute] == nil) {
                [managedObject setValue:[[self class] firebaseKey] forKey:self.coreDataKeyAttribute];
            }
        };

        if ([self.observedManagedObjectContext hasChanges]) {
            [self.observedManagedObjectContext save:nil];
        }
    }];
}

- (void)enumerateLinkedEntitiesUsingBlock:(void (^)(NSArray *, Firebase *))block
{
    [self enumerateLinkedEntitiesWithPredicate:nil usingBlock:block];
}

- (void)enumerateLinkedEntitiesWithPredicate:(NSPredicate *)predicate usingBlock:(void (^)(NSArray *, Firebase *))block
{
    [self.linkedEntities enumerateKeysAndObjectsUsingBlock:^(NSString *coreDataEntity, Firebase *firebase, BOOL *stop) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:coreDataEntity];
        fetchRequest.predicate = predicate;
        [fetchRequest setFetchBatchSize:25];
        NSError *error;
        NSArray *managedObjects = [self.observedManagedObjectContext executeFetchRequest:fetchRequest error:&error];
        NSAssert(!error, @"%@", error);

        block(managedObjects, firebase);
    }];
}

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
    if (notification.object == self.writeManagedObjectContext || self.ignoreManagedObjectSaveNotification == YES) {
        return;
    }
    NSSet *deletedObjects = [notification userInfo][NSDeletedObjectsKey];
    NSMutableDictionary *firebaseUpdateDictionary = [NSMutableDictionary new];
    //TODO: Make deletion own method
    for (NSManagedObject *managedObject in deletedObjects) {
        Firebase *firebase = [self firebaseForCoreDataEntity:[[managedObject entity] name]];
        Firebase *indexFirebase = self.indexEntities[[[managedObject entity] name]];

        if (firebase) {
            Firebase *child = [firebase childByAppendingPath:[self firebaseSyncValueForManagedObject:managedObject]];
            NSURL *childURL = [NSURL URLWithString:[child description]];
            firebaseUpdateDictionary[childURL.path] = [NSNull null];
        }

        if (indexFirebase) {
            Firebase *indexChild = [indexFirebase childByAppendingPath:[self firebaseSyncValueForManagedObject:managedObject]];
            NSURL *childURL = [NSURL URLWithString:[indexChild description]];
            firebaseUpdateDictionary[childURL.path] = [NSNull null];
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
            [self updateFirebaseDictionary:firebaseUpdateDictionary forManagedObject:managedObject withFirebaseNode:firebase];
        }
    };

    [self updateFirebaseRootWithDictionary:firebaseUpdateDictionary];
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
    NSString *coreDataKey = [FireData coreDataSyncValueForFirebaseSyncValue:firebaseKey];
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:entityName];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"%K == %@", self.coreDataKeyAttribute, coreDataKey]];
    [fetchRequest setFetchLimit:1];
    NSError *error;
    NSManagedObject *managedObject = [[self.writeManagedObjectContext executeFetchRequest:fetchRequest error:&error] lastObject];
    NSAssert(!error, @"%@", error);
    return managedObject;
}

- (void)updateCoreDataEntity:(NSString *)entityName firebaseKey:(NSString *)firebaseKey properties:(NSDictionary *)properties
{
    if ((id)properties == [NSNull null]) return;

    [self.writeManagedObjectContext performBlock:^{
        NSManagedObject *managedObject = [self fetchCoreDataManagedObjectWithEntityName:entityName firebaseKey:firebaseKey];
        if (!managedObject) {
            managedObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.writeManagedObjectContext];
            [managedObject setValue:[FireData coreDataSyncValueForFirebaseSyncValue:firebaseKey] forKey:self.coreDataKeyAttribute];
        }

        [managedObject firedata_setPropertiesForKeysWithDictionary:properties coreDataKeyAttribute:self.coreDataKeyAttribute coreDataDataAttribute:self.coreDataDataAttribute];

        if ([self.writeManagedObjectContext hasChanges] && self.writeManagedObjectContextCompletionBlock) {
            self.writeManagedObjectContextCompletionBlock(self.writeManagedObjectContext);
        }
    }];
}

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

    [self.writeManagedObjectContext performBlock:^{
        NSManagedObject *managedObject = [self fetchCoreDataManagedObjectWithEntityName:coreDataEntity firebaseKey:snapshot.key];
        if (managedObject) {
            [self.writeManagedObjectContext deleteObject:managedObject];

            if (self.writeManagedObjectContextCompletionBlock) {
                self.writeManagedObjectContextCompletionBlock(self.writeManagedObjectContext);
            }
        }
    }];
}

- (void)updateFirebaseRootWithDictionary:(NSDictionary *)dictionary {
    Firebase *firebaseRoot = [self firebaseRoot];
    NSAssert(firebaseRoot != nil, @"No firebase root found from linked entities: %@", self.linkedEntities);
    [firebaseRoot updateChildValues:dictionary withCompletionBlock:^(NSError *error, Firebase *ref) {
        NSAssert(!error, @"%@. Object is %@", error, dictionary);
    }];
}

- (void)updateFirebaseDictionary:(NSMutableDictionary * _Nonnull)firebaseDictionary forManagedObject:(NSManagedObject * _Nonnull)managedObject withFirebaseNode:(Firebase * _Nonnull)firebase {
    NSURL *childURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/%@", [firebase description], [self firebaseSyncValueForManagedObject:managedObject]]];
    NSDictionary *properties = [managedObject firedata_propertiesDictionaryWithCoreDataKeyAttribute:self.coreDataKeyAttribute coreDataDataAttribute:self.coreDataDataAttribute];
    for (NSString *propertyKey in properties.allKeys) {
        firebaseDictionary[[NSString stringWithFormat:@"%@/%@", childURL.path, propertyKey]] = properties[propertyKey];
    }

    Firebase *indexFirebase = self.indexEntities[[[managedObject entity] name]];
    if (indexFirebase) {
        Firebase *indexChild = [indexFirebase childByAppendingPath:[self firebaseSyncValueForManagedObject:managedObject]];
        NSURL *indexURL = [NSURL URLWithString:[indexChild description]];
        firebaseDictionary[indexURL.path] = @YES;
    }
}

- (NSString *)firebaseSyncValueForManagedObject:(NSManagedObject *)managedObject {
    NSString *syncValue = [managedObject valueForKey:self.coreDataKeyAttribute];
    return [FireData firebaseSyncValueFromCoreDataSyncValue:syncValue];
}

+ (NSString *)firebaseSyncValueFromCoreDataSyncValue:(NSString *)coreDataSyncValue {
    return [coreDataSyncValue stringByReplacingOccurrencesOfString:@"." withString:@"_@@_"];
}

+ (NSString *)coreDataSyncValueForFirebaseSyncValue:(NSString *)firebaseSyncValue {
    return [firebaseSyncValue stringByReplacingOccurrencesOfString:@"_@@_" withString:@"."];
}

-  (Firebase *)firebaseRoot {
    Firebase *firebaseNode = [self.linkedEntities.allValues firstObject];
    return firebaseNode.root;
}

@end
