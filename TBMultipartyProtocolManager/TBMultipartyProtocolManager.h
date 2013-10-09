//
//  TBMultipartyProtocolManager.h
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 04/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//

#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface TBMultipartyProtocolManager : NSObject

@property (nonatomic, readonly) NSString *privateKey;
@property (nonatomic, readonly) NSString *publicKey;
@property (nonatomic, strong) NSString *myName;

+ (TBMultipartyProtocolManager *)sharedMultipartyProtocolManager;

- (NSString *)publicKeyMessageForUsername:(NSString *)username;
- (BOOL)addPublicKeyFromMessage:(NSString *)publicKeyMessage forUsername:(NSString *)username;
+ (NSString *)md5FromString:(NSString *)string;

@end
