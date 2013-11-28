//
//  TBMultipartyProtocolManager.h
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 04/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
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