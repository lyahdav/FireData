//
//  SomeEntity.m
//  FireData
//
//  Created by Liron Yahdav on 9/10/15.
//  Copyright © 2015 Overcommitted, LLC. All rights reserved.
//

#import "SomeEntity.h"

@implementation SomeEntity

- (NSArray *)excludedFiredataProperties {
    return @[@"attributeToIgnore"];
}

- (void)convertCoreDataPropertiesToFirebase:(NSMutableDictionary *)properties {
    properties[@"computedAttribute"] = @"computed_value";
    
    id valueToTransform = properties[@"attributeToTransform"];
    if (valueToTransform && valueToTransform != [NSNull null]) {
        properties[@"attributeToTransform"] = [valueToTransform stringByAppendingString:@"_transformed"];
    }
}

- (void)convertFirebasePropertiesToCoreData:(NSMutableDictionary *)properties {
    id valueToTransform = properties[@"attributeToTransform"];
    
    if (valueToTransform && valueToTransform != [NSNull null]) {
        properties[@"attributeToTransform" ] = [valueToTransform stringByReplacingOccurrencesOfString:@"_transformed" withString:@""];
    }
}

@end
