//
//  SomeEntity+CoreDataProperties.h
//  FireData
//
//  Created by Liron Yahdav on 9/10/15.
//  Copyright © 2015 Overcommitted, LLC. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "SomeEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface SomeEntity (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *someAttribute;
@property (nullable, nonatomic, retain) NSString *firebaseData;
@property (nullable, nonatomic, retain) NSString *firebaseKey;

@end

NS_ASSUME_NONNULL_END
