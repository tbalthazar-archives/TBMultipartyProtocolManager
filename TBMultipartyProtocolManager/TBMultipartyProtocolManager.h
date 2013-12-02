//
//  TBMultipartyProtocolManager.h
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 04/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//
//  This file is part of TBMultipartyProtocolManager.
//
//  TBMultipartyProtocolManager is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  TBMultipartyProtocolManager is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public License
//  along with TBMultipartyProtocolManager.  If not, see <http://www.gnu.org/licenses/>.
//

#import <Foundation/Foundation.h>

extern NSString * const TBErrorDomainDecryption;
extern NSInteger const TBErrorCodeDecryptionMissingRecipients;
extern NSInteger const TBErrorCodeDecryptionIncorrectHMAC;
extern NSInteger const TBErrorCodeDecryptionIncorrectIV;
extern NSInteger const TBErrorCodeDecryptionIncorrectTag;
extern NSString * const TBMDecryptionMissingRecipientsKey;

@protocol TBMultipartyProtocolManagerDelegate;

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface TBMultipartyProtocolManager : NSObject

@property (nonatomic, weak) id <TBMultipartyProtocolManagerDelegate> delegate;
@property (nonatomic, readonly) NSString *privateKey;
@property (nonatomic, readonly) NSString *publicKey;
@property (nonatomic, readonly) NSString *fingerprint;
@property (nonatomic, strong) NSString *myName;

- (NSString *)publicKeyMessageForUsername:(NSString *)username;
- (BOOL)addPublicKeyFromMessage:(NSString *)publicKeyMessage forUsername:(NSString *)username;
- (BOOL)hasPublicKeyForUsername:(NSString *)username;
- (void)disconnectUsername:(NSString *)username;
- (NSString *)encryptMessage:(NSString *)message forUsernames:(NSArray *)usernames;
- (NSString *)decryptMessage:(NSString *)message
                fromUsername:(NSString *)username
                       error:(NSError **)error;
- (NSString *)fingerprintForUsername:(NSString *)username;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@protocol TBMultipartyProtocolManagerDelegate <NSObject>

- (void)multipartyProtocolManager:(TBMultipartyProtocolManager *)manager
didEstablishSecureConnectionWithUsername:(NSString *)username;

@end