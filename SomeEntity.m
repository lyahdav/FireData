//
//  SomeEntity.m
//  FireData
//
//  Created by Liron Yahdav on 9/10/15.
//  Copyright © 2015 Overcommitted, LLC. All rights reserved.
//

#import "SomeEntity.h"

@implementation SomeEntity

- (NSArray*)excludedFiredataProperties {
    return @[@"attributeToIgnore"];
}

- (id)convertAttributeToTransformFromFirebaseValue:(id)value {
    return [value stringByAppendingString:@"_transformed"];
}

- (id)convertAttributeToTransformFromCoreDataValue:(id)value {
    return [value stringByReplacingOccurrencesOfString:@"_transformed" withString:@""];
}
@end
