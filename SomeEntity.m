//
//  SomeEntity.m
//  FireData
//
//  Created by Liron Yahdav on 9/10/15.
//  Copyright © 2015 Overcommitted, LLC. All rights reserved.
//

#import "SomeEntity.h"

@implementation SomeEntity

- (void)convertCoreDataPropertiesToFirebase:(NSMutableDictionary *)properties {
    [properties removeObjectForKey:@"attributeToIgnore"];
    properties[@"computedAttribute"] = @"computed_value";
    
    id valueToTransform = properties[@"attributeToTransform"];
    if (valueToTransform != [NSNull null]) {
        properties[@"attributeToTransform"] = [valueToTransform stringByAppendingString:@"_transformed"];
    }
}

- (void)convertFirebasePropertiesToCoreData:(NSMutableDictionary *)properties {
    id valueToTransform = properties[@"attributeToTransform"];
    
    if (valueToTransform) {
        properties[@"attributeToTransform" ] = [valueToTransform stringByReplacingOccurrencesOfString:@"_transformed" withString:@""];
    }
}

@end
