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

@end
