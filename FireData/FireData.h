//
//  FireData.h
//  FireData
//
//  Created by Jonathan Younger on 3/20/13.
//  Copyright (c) 2013 Overcommitted, LLC. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import <Foundation/Foundation.h>
#import <Firebase/Firebase.h>
#import <CoreData/CoreData.h>

@interface FireData : NSObject

/**
* Set this property to the Core Data unique key attribute used by Firebase.
* @default firebaseKey
* @return The Core Data unique key attribute
*/
@property (copy, nonatomic) NSString *coreDataKeyAttribute;

/**
* Set this property to the Core Data data attribute used by Firebase.
* @default firebaseData
* @return The Core Data data attribute
*/
@property (copy, nonatomic) NSString *coreDataDataAttribute;

/**
* @return A new unique key
*/
+ (NSString *)firebaseKey;

/**
* Convert sync ID values from Firebase to Core Data
*/
+ (NSString *)coreDataSyncValueForFirebaseSyncValue:(NSString *)firebaseSyncValue;

/**
* Convert sync ID values from Core Data to Firebase
*/
+ (NSString *)firebaseSyncValueFromCoreDataSyncValue:(NSString *)coreDataSyncValue;

/**
* observeManagedObjectContext: is used to listen for data changes for the specified managed object context.
*
* @param managedObjectContext The managed object context to listen for changes on.
*/
- (void)observeManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
* setWriteManagedObjectContext:withCompletionBlock: is used to write changes from Firebase to the specified managed object context.
*
* @param managedObjectContext The managed object context to write changes to.
* @param block The block that should be called to save changes written to the managed object context.
*/
- (void)setWriteManagedObjectContext:(NSManagedObjectContext *)writeManagedObjectContext withCompletionBlock:(void (^)(NSManagedObjectContext *error))block;

/**
* linkCoreDataEntity:withFirebase: is used to specify which Core Data entity to synchronize changes with the specified Firebase.
*
* @param coreDataEntity The Core Data entity name to listen for changes to.
* @param firebase The Firebase reference to listen for changes to.
*/
- (void)linkCoreDataEntity:(NSString *)coreDataEntity withFirebase:(Firebase *)firebase;

- (void)linkCoreDataEntity:(NSString *)coreDataEntity withFirebase:(Firebase *)firebase withIndex:(Firebase *)indexFirebase;

/**
* unlinkCoreDataEntity: is used to remove the link between the Core Data entity and the associated Firebase.
*
* @param coreDataEntity The Core Data entity name to unlink.
*/
- (void)unlinkCoreDataEntity:(NSString *)coreDataEntity;

/**
* Unlinks all previously linked Core Data entities from FireBase
*/
- (void)unlinkAllCoreDataEntities;

/**
* Starts observing changes between Core Data and Firebase.
*/
- (void)startObserving;

/**
* Stops observing changes between Core Data and Firebase.
*/
- (void)stopObserving;

/**
* Upload Core Data objects that are not already in Firebase.
*
* @param snapshot a snapshot of Firebase data. This is used to determine which Core Data objects should be uploaded.
*/
- (void)uploadMissingCoreDataObjectsToFirebase:(FDataSnapshot *)snapshot;

/**
* Adds randomly-generated firebase keys to all linked entities that don't have a key yet.
*/
- (void)addMissingFirebaseKeyToCoreDataObjects;

@end
