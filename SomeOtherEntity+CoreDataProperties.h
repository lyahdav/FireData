//
//  SomeOtherEntity+CoreDataProperties.h
//  FireData
//
//  Created by kriser gellci on 10/2/15.
//  Copyright © 2015 Overcommitted, LLC. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "SomeOtherEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface SomeOtherEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSString *firebaseData;
@property (nullable, nonatomic, retain) NSString *firebaseKey;
@property (nullable, nonatomic, retain) SomeEntity *someEntity;

@end

NS_ASSUME_NONNULL_END
