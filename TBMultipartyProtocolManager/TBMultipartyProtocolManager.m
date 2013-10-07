//
//  TBMultipartyProtocolManager.m
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 04/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//

#import "TBMultipartyProtocolManager.h"
#import "curve25519-donna.h"
#import "NSData+Base64.h"
#import "NSString+TBMultipartyProtocolManager.h"
#import <CommonCrypto/CommonDigest.h>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface TBMultipartyProtocolManager ()

@property (nonatomic, strong, readwrite) NSString *privateKey;
@property (nonatomic, strong, readwrite) NSString *publicKey;
@property (nonatomic, strong) NSMutableDictionary *publicKeys;
@property (nonatomic, strong) NSMutableDictionary *sharedSecrets;

- (NSString *)generateSharedSecretForUsername:(NSString *)username;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation TBMultipartyProtocolManager

static TBMultipartyProtocolManager *sharedMultipartyProtocolManager = nil;

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initializer

///////////////////////////////////////////////////////////////////////////////////////////////////
+ (TBMultipartyProtocolManager *)sharedMultipartyProtocolManager {
  if (sharedMultipartyProtocolManager==nil) {
    sharedMultipartyProtocolManager = [[self alloc] init];
  }
  
  return sharedMultipartyProtocolManager;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)init {
  if (self=[super init]) {
    // generate a private key (32 random bytes)
    uint8_t private_key[32];
    private_key[0] &= 248;
    private_key[31] &= 127;
    private_key[31] |= 64;
    
    // generate public key
    uint8_t public_key[32];
    static const uint8_t basepoint[32] = {9};
    curve25519_donna(public_key, private_key, basepoint);
    
    NSData *publicKeyData = [NSData dataWithBytes:public_key length:sizeof(public_key)];
    NSData *privateKeyData = [NSData dataWithBytes:private_key length:sizeof(private_key)];
    
    _privateKey = [privateKeyData base64EncodedString];
    _publicKey = [publicKeyData base64EncodedString];
    
    _publicKeys = [NSMutableDictionary dictionary];
    _sharedSecrets = [NSMutableDictionary dictionary];
    _myName = nil;
  }
  
  return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private Methods

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)generateSharedSecretForUsername:(NSString *)username {
  // keys are stored base64 encoded
  NSData *decodedPublicKey = [NSData dataFromBase64String:self.publicKey];
  NSData *decodedPrivateKey = [NSData dataFromBase64String:self.privateKey];
  
  const void *public_key_bytes = [decodedPublicKey bytes];
  uint8_t *public_key = (uint8_t *)public_key_bytes;

  const void *private_key_bytes = [decodedPrivateKey bytes];
  uint8_t *private_key = (uint8_t *)private_key_bytes;
  
  uint8_t shared_secret[32];
  curve25519_donna(shared_secret, private_key, public_key);
  
  NSData *sharedSecretData = [NSData dataWithBytes:shared_secret length:sizeof(shared_secret)];
  NSLog(@"-- sharedSecretData %@ | %d bytes", sharedSecretData, sharedSecretData.length);
  
  // sha512 the shared secret
  uint8_t digest[CC_SHA512_DIGEST_LENGTH] = {0};
  CC_SHA512(sharedSecretData.bytes, sharedSecretData.length, digest);
  sharedSecretData = [NSData dataWithBytes:digest length:CC_SHA512_DIGEST_LENGTH];
  NSLog(@"-- sharedSecretData %@ | %d bytes", sharedSecretData, sharedSecretData.length);
  
  return [sharedSecretData base64EncodedString];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Public Methods

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)publicKeyMessageForUsername:(NSString *)username {
  /*
  { 
    "type":"publicKey",
    "text":{
      "iOSTestApp":{
        "message":"6ZpMAta860/myjWIkwgFj1fMaLgTcdCMeYtnd6O0q1Y="
      }
    }
  }
  */
  NSDictionary *messageDic = @{@"message": self.publicKey};
  NSDictionary *usernameDic = @{username: messageDic};
  NSDictionary *fullDic = @{@"type": @"publicKey", @"text": usernameDic};

  return [NSString tb_stringFromJSONObject:fullDic];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)addPublicKeyFromMessage:(NSString *)publicKeyMessage forUsername:(NSString *)username {
  NSDictionary *JSONDic = [NSString tb_JSONStringToDictionary:publicKeyMessage];
  
  // get my name
  NSString *myName = [[[JSONDic objectForKey:@"text"] allKeys] lastObject];
  
  if (![myName isEqualToString:self.myName]) return NO;
  
  // get public key
  NSString *publicKey = [[[JSONDic objectForKey:@"text"]
                         objectForKey:myName] objectForKey:@"message"];
  
  if ([self.publicKeys objectForKey:username]==nil) {
    [self.publicKeys setObject:publicKey forKey:username];
    [self.sharedSecrets setObject:[self generateSharedSecretForUsername:username] forKey:username];
  }
  
  return YES;
}

@end
