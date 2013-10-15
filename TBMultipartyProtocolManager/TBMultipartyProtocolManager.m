//
//  TBMultipartyProtocolManager.m
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 04/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//

#import "TBMultipartyProtocolManager.h"
#import "NSString+TBMultipartyProtocolManager.h"
#import "NSData+TBMultipartyProtocolManager.h"
#import "TBMultipartyChatMessage.h"
#import <CommonCrypto/CommonDigest.h> // TODO: use OpenSSL instead of Apple's implementation

#import "curve25519-donna.h"
#import "aes.h"
#import "hmac.h"
#import "sha.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface TBMultipartyProtocolManager ()

// keys are stored as base64 encoded strings
@property (nonatomic, strong, readwrite) NSString *privateKey;
@property (nonatomic, strong, readwrite) NSString *publicKey;
@property (nonatomic, strong) NSMutableDictionary *publicKeys;
@property (nonatomic, strong) NSMutableArray *usedIVs;

// shared secrets are stored as (non base64) NSData
@property (nonatomic, strong) NSMutableDictionary *sharedSecrets;
@property (nonatomic, strong) NSMutableDictionary *fingerprints;

- (NSData *)generateSharedSecretForUsername:(NSString *)username;
- (NSString *)generateFingerprintForUsername:(NSString *)username;
- (BOOL)checkHMACForChatMessage:(TBMultipartyChatMessage *)chatMessage;
- (BOOL)checkIVFirstUseForChatMessage:(TBMultipartyChatMessage *)chatMessage;
- (BOOL)checkTagForChatMessage:(TBMultipartyChatMessage *)chatMessage
                 decryptedData:(NSData *)decryptedData;

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

    // store the base64 encoded version
    NSData *publicKeyData = [NSData dataWithBytes:public_key length:sizeof(public_key)];
    NSData *privateKeyData = [NSData dataWithBytes:private_key length:sizeof(private_key)];
    
    _privateKey = [privateKeyData tb_base64String];
    _publicKey = [publicKeyData tb_base64String];
    
    _publicKeys = [NSMutableDictionary dictionary];
    _sharedSecrets = [NSMutableDictionary dictionary];
    _fingerprints = [NSMutableDictionary dictionary];
    _myName = nil;
    _usedIVs = [NSMutableArray array];
  }
  
  return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Private Methods

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSData *)generateSharedSecretForUsername:(NSString *)username {
  // get my base64 decoded private key and username's base64 decode public key
  NSString *publicKey = [self.publicKeys objectForKey:username];
  NSData *decodedPublicKey = [NSData tb_dataFromBase64String:publicKey];
  NSData *decodedPrivateKey = [NSData tb_dataFromBase64String:self.privateKey];
  
  uint8_t *public_key = (uint8_t *)[decodedPublicKey bytes];
  uint8_t *private_key = (uint8_t *)[decodedPrivateKey bytes];
  
  // generate a shared secret
  uint8_t shared_secret[32];
  curve25519_donna(shared_secret, private_key, public_key);
  
  // sha512 the shared secret
  uint8_t digest[CC_SHA512_DIGEST_LENGTH] = {0};
  CC_SHA512(shared_secret, sizeof(shared_secret), digest);
  NSData *sharedSecretData = [NSData dataWithBytes:digest length:CC_SHA512_DIGEST_LENGTH];
  
  return sharedSecretData;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)generateFingerprintForUsername:(NSString *)username {
  NSData *publicKeyData = [[NSData alloc] initWithBase64EncodedString:self.publicKey
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];

  uint8_t digest[CC_SHA512_DIGEST_LENGTH] = {0};
  CC_SHA512(publicKeyData.bytes, publicKeyData.length, digest);
  publicKeyData = [NSData dataWithBytes:digest length:CC_SHA512_DIGEST_LENGTH];
  NSLog(@"-- publicKeyData %@ | %d bytes", publicKeyData, publicKeyData.length);
  
  NSString *fingerprint = [publicKeyData
                          base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
  
  return [fingerprint substringWithRange:NSMakeRange(0, 40)];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)checkHMACForChatMessage:(TBMultipartyChatMessage *)chatMessage {
  /*
  HMACs are generated by running the concatenation of the ciphertext-IV pairs for every party 
   in the conversation (including the sender) : 
   ciphertextAlice || IValice || ciphertextBob || IVbob || ciphertextCarol || IVcarol || ... 
   (arranged by sorting the recipient nicknames lexicographically) through HMAC-SHA-512.
   The sender N uses the last 256 bits of sharedSecretNM as the HMAC key for the ciphertext 
   sent to the user M. They are stored inside the message's text object, 
   which is part of the transmitted JSON. HMACs are stored and communicated in Base 64 format.
  */
  
  // concat the message elements for the hmac function
  NSMutableData *hmacData = [NSMutableData data];
  for (NSString *username in chatMessage.usernames) {
    NSData *decodedMessage = [chatMessage.messageForUsernames objectForKey:username];
    NSData *decodedIV = [chatMessage.ivForUsernames objectForKey:username];
    [hmacData appendData:decodedMessage];
    [hmacData appendData:decodedIV];
  }
  
  // get the key that will be used for the hmac function
  NSData *sharedSecretData = [self.sharedSecrets objectForKey:chatMessage.senderName];
  unsigned char hmac_key[32];
  [sharedSecretData getBytes:hmac_key range:NSMakeRange(32, 32)];

  // compute the hmac for the message
  unsigned char computed_hmac[EVP_MAX_MD_SIZE];
  unsigned int computed_hmac_length;
  
  HMAC(EVP_sha512(), hmac_key, 32,            // hash function, key, key length
       hmacData.bytes, hmacData.length,       // data, data length
       computed_hmac, &computed_hmac_length); // output, output length

  // compare the computed hmac with the received hmac
  NSData *computedHmacData = [NSData dataWithBytes:computed_hmac length:computed_hmac_length];
  NSData *receivedHMACData = [chatMessage.hmacForUsernames objectForKey:self.myName];
  
  return [computedHmacData isEqualToData:receivedHMACData];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)checkIVFirstUseForChatMessage:(TBMultipartyChatMessage *)chatMessage {
  NSData *iv = [chatMessage.ivForUsernames objectForKey:self.myName];
  return ![self.usedIVs containsObject:iv];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)checkTagForChatMessage:(TBMultipartyChatMessage *)chatMessage
                 decryptedData:(NSData *)decryptedData {
  NSMutableData *computedTag = [NSMutableData dataWithData:decryptedData];
  for (NSString *username in chatMessage.usernames) {
    [computedTag appendData:[chatMessage.hmacForUsernames objectForKey:username]];
  }
  
  unsigned char digest[SHA512_DIGEST_LENGTH];
  for (NSInteger i=0; i<8; i++) {
    SHA512(computedTag.bytes, computedTag.length, digest);
    computedTag = [NSMutableData dataWithBytes:digest length:sizeof(digest)];
  }
  
  return [computedTag isEqualToData:chatMessage.tag];
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
    [self.fingerprints setObject:[self generateFingerprintForUsername:username] forKey:username];
  }
  
  return YES;
}

struct ctr_state {
  unsigned char ivec[AES_BLOCK_SIZE];
  unsigned int num;
  unsigned char ecount[AES_BLOCK_SIZE];
};

void init_ctr(struct ctr_state *state, const unsigned char iv[12]) {
  /* aes_ctr128_encrypt requires 'num' and 'ecount' set to zero on the * first call. */
  state->num = 0;
  memset(state->ecount, 0, AES_BLOCK_SIZE);
  /* Initialise counter in 'ivec' to 0 */
  memset(state->ivec + 12, 0, 4);
  /* Copy IV into 'ivec' */
  memcpy(state->ivec, iv, 12);
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)encryptMessage:(NSString *)message forUsername:(NSString *)username {
  return nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)decryptMessage:(NSString *)message fromUsername:(NSString *)username {
  TBMultipartyChatMessage *chatMessage = [[TBMultipartyChatMessage alloc]
                                          initWithJSONMessage:message senderName:username];
  
  // check HMAC
  if (![self checkHMACForChatMessage:chatMessage]) return nil;
  
  // check IV reuse
  if (![self checkIVFirstUseForChatMessage:chatMessage]) return nil;
  [self.usedIVs addObject:[chatMessage.ivForUsernames objectForKey:self.myName]];
  
  // get shared secret
  NSData *sharedSecretData = [self.sharedSecrets objectForKey:username];
  unsigned char enc_key[32];
  [sharedSecretData getBytes:enc_key range:NSMakeRange(0, 32)];
  
  // aes vars
  AES_KEY key;
  unsigned char indata[AES_BLOCK_SIZE];
  unsigned char outdata[AES_BLOCK_SIZE];
  unsigned char iv[12];
  struct ctr_state state;
  
  // get IV
  NSData *ivData = [chatMessage.ivForUsernames objectForKey:self.myName];
  [ivData getBytes:iv range:NSMakeRange(0, 12)];
  
  // initializing the encryption KEY
  if (AES_set_encrypt_key(enc_key, 256, &key) < 0) {
    NSLog(@"-- error initializing private key");
  }
  
  // After we set our encryption key we need to initialize our state structure which holds our IV.
  init_ctr(&state, iv); // Counter call

  // Decrypt the data in AES_BLOCK_SIZE bytes blocks
  NSData *cyphertextData = [chatMessage.messageForUsernames objectForKey:self.myName];
  NSMutableData *decryptedData = [NSMutableData data];
  NSUInteger cyphertextDataLength = cyphertextData.length;
  NSUInteger byteRangeStart = 0;
  NSUInteger byteRangeLength = AES_BLOCK_SIZE;
  NSUInteger byteRangeMax = byteRangeStart + byteRangeLength;
  
  // text to decrypt will be read in AES_BLOCK_SIZE chunks, make sure not to read more
  // than the actual size of the text
  if (byteRangeMax > cyphertextDataLength) {
    byteRangeLength = cyphertextDataLength - byteRangeStart;
  }
  NSRange bytesRange = NSMakeRange(byteRangeStart, byteRangeLength);
  
  while (byteRangeStart < cyphertextDataLength) {
    // get some bytes to decrypt in the indata char array
    [cyphertextData getBytes:indata range:bytesRange];
    
    // decrypt those bytes
    AES_ctr128_encrypt(indata, outdata, byteRangeLength,
                       &key, state.ivec, state.ecount, &state.num);
    
    // store those decrypted bytes in the nsdata var
    [decryptedData appendBytes:outdata length:byteRangeLength];
    
    // compute the next range of byte to decrypt
    byteRangeStart+=byteRangeLength;
    byteRangeMax = byteRangeStart + byteRangeLength;
    if (byteRangeMax > cyphertextDataLength) {
      byteRangeLength = cyphertextDataLength - byteRangeStart;
    }
    bytesRange = NSMakeRange(byteRangeStart, byteRangeLength);
  }
  
  // check tag
  if (![self checkTagForChatMessage:chatMessage decryptedData:decryptedData]) return nil;
  
  // remove padding
  NSUInteger decryptedDataLength = decryptedData.length;
  [decryptedData setLength:decryptedDataLength-64];
  
  return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
}


@end
