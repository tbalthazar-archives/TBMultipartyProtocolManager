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

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface TBMultipartyProtocolManager ()

@property (nonatomic, strong, readwrite) NSString *privateKey;
@property (nonatomic, strong, readwrite) NSString *publicKey;
@property (nonatomic, strong) NSMutableDictionary *publicKeys;

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
    _myName = nil;
  }
  
  return self;
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
  [self.publicKeys setObject:publicKey forKey:username];
  
  return YES;
}

@end
