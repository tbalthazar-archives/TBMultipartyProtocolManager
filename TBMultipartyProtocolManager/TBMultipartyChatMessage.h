//
//  TBMultipartyChatMessage.h
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 11/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//

#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface TBMultipartyChatMessage : NSObject

@property (nonatomic, readonly) NSArray *usernames;
@property (nonatomic, readonly) NSDictionary *messageForUsernames;
@property (nonatomic, readonly) NSDictionary *ivForUsernames;
@property (nonatomic, readonly) NSDictionary *hmacForUsernames;
@property (nonatomic, readonly) NSString *tag;

- (id)initWithJSONMessage:(NSString *)JSONMessage;

@end