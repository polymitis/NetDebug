//
//  AppDelegate.h
//  NetDebug
//
//  Created by Petros Fountas on 26/11/14.
//  Copyright (c) 2014 Petros Fountas. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "DataModel.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) DataModel *dataModel;

@end

