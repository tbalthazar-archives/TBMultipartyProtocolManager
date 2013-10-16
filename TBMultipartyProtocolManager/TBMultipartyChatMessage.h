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

@property (nonatomic, strong) NSString *senderName;
@property (nonatomic, strong) NSArray *usernames;
@property (nonatomic, strong) NSDictionary *messageForUsernames;
@property (nonatomic, strong) NSDictionary *ivForUsernames;
@property (nonatomic, strong) NSDictionary *hmacForUsernames;
@property (nonatomic, strong) NSData *tag;

- (id)initWithJSONMessage:(NSString *)JSONMessage senderName:(NSString *)senderName;
- (NSString *)toJSONString;

@end