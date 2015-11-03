//
//  SomeEntity+CoreDataProperties.h
//  FireData
//
//  Created by kriser gellci on 10/19/15.
//  Copyright © 2015 Overcommitted, LLC. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "SomeEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface SomeEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *firebaseData;
@property (nullable, nonatomic, retain) NSString *firebaseKey;
@property (nullable, nonatomic, retain) NSString *someAttribute;
@property (nullable, nonatomic, retain) NSString *attributeToIgnore;
@property (nullable, nonatomic, retain) NSString *attributeToTransform;
@property (nullable, nonatomic, retain) NSSet<NSManagedObject *> *someOtherEntities;

@end

@interface SomeEntity (CoreDataGeneratedAccessors)

- (void)addSomeOtherEntitiesObject:(NSManagedObject *)value;
- (void)removeSomeOtherEntitiesObject:(NSManagedObject *)value;
- (void)addSomeOtherEntities:(NSSet<NSManagedObject *> *)values;
- (void)removeSomeOtherEntities:(NSSet<NSManagedObject *> *)values;

@end

NS_ASSUME_NONNULL_END
