//
//  TBMultipartyProtocolManager.m
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

#import "TBMultipartyProtocolManager.h"
#import "NSString+TBMultipartyProtocolManager.h"
#import "NSData+TBMultipartyProtocolManager.h"
#import "TBMultipartyChatMessage.h"
#import <CommonCrypto/CommonDigest.h> // TODO: use OpenSSL instead of Apple's implementation

#import "curve25519-donna.h"
#import "aes.h"
#import "hmac.h"
#import "sha.h"
#import "rand.h"

NSString * const TBErrorDomainDecryption = @"TBErrorDomainDecryption";
NSInteger const TBErrorCodeDecryptionMissingRecipients = 13001;
NSInteger const TBErrorCodeDecryptionIncorrectHMAC = 13002;
NSInteger const TBErrorCodeDecryptionIncorrectIV = 13003;
NSInteger const TBErrorCodeDecryptionIncorrectTag = 13004;
NSString * const TBMDecryptionMissingRecipientsKey = @"TBMDecryptionMissingRecipientsKey";

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface TBMultipartyProtocolManager ()

// keys are stored as base64 encoded strings
@property (nonatomic, strong, readwrite) NSString *privateKey;
@property (nonatomic, strong, readwrite) NSString *publicKey;
@property (nonatomic, strong, readwrite) NSString *fingerprint;
@property (nonatomic, strong) NSMutableDictionary *publicKeys;
@property (nonatomic, strong) NSMutableArray *usedIVs;

// shared secrets are stored as (non base64) NSData
@property (nonatomic, strong) NSMutableDictionary *sharedSecrets;
@property (nonatomic, strong) NSMutableDictionary *fingerprints;

- (NSData *)generateSharedSecretForUsername:(NSString *)username;
- (NSString *)generateFingerprintForUsername:(NSString *)username;
- (NSData *)hmacFromData:(NSData *)hmacData forUsername:(NSString *)username;
- (NSArray *)checkForMissingRecipients:(TBMultipartyChatMessage *)chatMessage
                             usernames:(NSArray *)usernames;
- (BOOL)checkHMACForChatMessage:(TBMultipartyChatMessage *)chatMessage;
- (BOOL)checkIVFirstUseForChatMessage:(TBMultipartyChatMessage *)chatMessage;
- (BOOL)checkTagForChatMessage:(TBMultipartyChatMessage *)chatMessage
                 decryptedData:(NSData *)decryptedData;
- (NSData *)generateIV;
- (NSData *)encryptMessage:(NSData *)cyphertextData
               forUsername:(NSString *)username
                        iv:(NSData *)ivData;

@end

struct ctr_state {
  unsigned char ivec[AES_BLOCK_SIZE];
  unsigned int num;
  unsigned char ecount[AES_BLOCK_SIZE];
};

////////////////////////////////////////////////////////////////////////////////////////////////////
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
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation TBMultipartyProtocolManager

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Initializer

///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)init {
  if (self=[super init]) {
    // generate a private key (32 random bytes)
    uint8_t private_key[32];
    RAND_bytes(private_key, 32);
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
    _fingerprint = nil;
    
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
  // fingerprintN = SHA-512(publicKeyN).substring(0, 40) in HEX
  
  NSString *publicKey = nil;
  if ([username isEqualToString:self.myName]) {
    publicKey = self.publicKey;
  }
  else {
    publicKey = [self.publicKeys objectForKey:username];
  }
  
  NSData *publicKeyData = [NSData tb_dataFromBase64String:publicKey];

  uint8_t digest[CC_SHA512_DIGEST_LENGTH] = {0};
  CC_SHA512(publicKeyData.bytes, publicKeyData.length, digest);
  publicKeyData = [NSData dataWithBytes:digest length:CC_SHA512_DIGEST_LENGTH];
  NSLog(@"-- publicKeyData %@ | %d bytes", publicKeyData, publicKeyData.length);
  
  // convert to hex string
  NSMutableString *hexValue = [NSMutableString string];
  for (int i=0; i < CC_SHA512_DIGEST_LENGTH; i++) {
    [hexValue appendString:[NSString stringWithFormat:@"%02X", digest[i]]];
  }
  
  hexValue = [NSMutableString stringWithString:[hexValue substringWithRange:NSMakeRange(0, 40)]];
  
  for (NSUInteger i=39; i > 0; i--) {
    if (i%8==0) {
      [hexValue insertString:@" " atIndex:i];
    }
  }
  
  return hexValue;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSData *)hmacFromData:(NSData *)hmacData forUsername:(NSString *)username {
  // get the key that will be used for the hmac function
  NSData *sharedSecretData = [self.sharedSecrets objectForKey:username];
  unsigned char hmac_key[32];
  [sharedSecretData getBytes:hmac_key range:NSMakeRange(32, 32)];
  
  // compute the hmac for the message
  unsigned char computed_hmac[EVP_MAX_MD_SIZE];
  unsigned int computed_hmac_length;
  
  HMAC(EVP_sha512(), hmac_key, 32,            // hash function, key, key length
       hmacData.bytes, hmacData.length,       // data, data length
       computed_hmac, &computed_hmac_length); // output, output length
  
  return [NSData dataWithBytes:computed_hmac length:computed_hmac_length];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSArray *)checkForMissingRecipients:(TBMultipartyChatMessage *)chatMessage
                             usernames:(NSArray *)usernames {
  NSMutableArray *missingUsernames = [NSMutableArray array];
  
  for (NSString *username in usernames) {
    if (![chatMessage.usernames containsObject:username] ||
        [chatMessage.ivForUsernames objectForKey:username]==nil ||
        [chatMessage.hmacForUsernames objectForKey:username]==nil) {
      [missingUsernames addObject:username];
    }
  }
  
  return missingUsernames;
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
  
  // compare the computed hmac with the received hmac
  NSData *computedHmacData = [self hmacFromData:hmacData forUsername:chatMessage.senderName];
  NSData *receivedHMACData = [chatMessage.hmacForUsernames objectForKey:self.myName];
  
  return [computedHmacData isEqualToData:receivedHMACData];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)checkIVFirstUseForChatMessage:(TBMultipartyChatMessage *)chatMessage {
  NSData *iv = [chatMessage.ivForUsernames objectForKey:self.myName];
  return ![self.usedIVs containsObject:iv];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSData *)tagFromData:(NSData *)tagData {
  NSMutableData *computedTag = [NSMutableData dataWithData:tagData];
  unsigned char digest[SHA512_DIGEST_LENGTH];
  
  for (NSInteger i=0; i<8; i++) {
    SHA512(computedTag.bytes, computedTag.length, digest);
    computedTag = [NSMutableData dataWithBytes:digest length:sizeof(digest)];
  }

  return computedTag;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)checkTagForChatMessage:(TBMultipartyChatMessage *)chatMessage
                 decryptedData:(NSData *)decryptedData {
  NSMutableData *computedTag = [NSMutableData dataWithData:decryptedData];
  for (NSString *username in chatMessage.usernames) {
    [computedTag appendData:[chatMessage.hmacForUsernames objectForKey:username]];
  }
  
  return [[self tagFromData:computedTag] isEqualToData:chatMessage.tag];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSData *)generateIV {
  unsigned char iv[12];
  NSData *ivData;
  
  // make sure not to reuse a iv
  do {
    RAND_bytes(iv, 12);
    ivData = [NSData dataWithBytes:iv length:12];
  } while ([self.usedIVs containsObject:ivData]);
  [self.usedIVs addObject:ivData];

  return ivData;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSData *)encryptMessage:(NSData *)cyphertextData
               forUsername:(NSString *)username
                        iv:(NSData *)ivData {
  AES_KEY key;
  unsigned char enc_key[32];
  unsigned char indata[AES_BLOCK_SIZE];
  unsigned char outdata[AES_BLOCK_SIZE];
  unsigned char iv[12];
  struct ctr_state state;

  // get shared secret
  NSData *sharedSecretData = [self.sharedSecrets objectForKey:username];
  [sharedSecretData getBytes:enc_key range:NSMakeRange(0, 32)];

  // get the iv
  [ivData getBytes:iv range:NSMakeRange(0, 12)];
  
  // initializing the encryption KEY
  if (AES_set_encrypt_key(enc_key, 256, &key) < 0) {
    NSLog(@"-- error initializing private key");
  }

  // After we set our encryption key we need to initialize our state structure which holds our IV.
  init_ctr(&state, iv); // Counter call

  // Decrypt the data in AES_BLOCK_SIZE bytes blocks
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

  return decryptedData;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Public Methods

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)fingerprint {
  if (_fingerprint==nil) {
    _fingerprint = [self generateFingerprintForUsername:self.myName];
  }
  
  return _fingerprint;
}

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
  
  if ([self.delegate respondsToSelector:
       @selector(multipartyProtocolManager:didEstablishSecureConnectionWithUsername:)]) {
    [self.delegate multipartyProtocolManager:self
    didEstablishSecureConnectionWithUsername:username];
  }
  
  return YES;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)hasPublicKeyForUsername:(NSString *)username {
  return [self.publicKeys objectForKey:username]!=nil;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (void)disconnectUsername:(NSString *)username {
  [self.publicKeys removeObjectForKey:username];
  [self.sharedSecrets removeObjectForKey:username];
  [self.fingerprints removeObjectForKey:username];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)encryptMessage:(NSString *)message forUsernames:(NSArray *)usernames {
  NSMutableData *messageData = [NSMutableData dataWithData:
                                [message dataUsingEncoding:NSUTF8StringEncoding]];
  
  // add 64 bytes of padding
  unsigned char random_bytes[64];
  RAND_bytes(random_bytes, 64);
  [messageData appendBytes:random_bytes length:64];
  
  // sort usernames
  usernames = [usernames sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  
  NSMutableDictionary *ivForUsernames = [NSMutableDictionary dictionary];
  NSMutableDictionary *messageForUsernames = [NSMutableDictionary dictionary];
  NSMutableDictionary *hmacForUsernames =  [NSMutableDictionary dictionary];
  NSMutableData *hmacData = [NSMutableData data];
  
  // for each username, encrypt the message and build the hmacData
  for (NSString *username in usernames) {
    NSData *ivData = [self generateIV];
    [ivForUsernames setObject:ivData forKey:username];
    
    NSData *encryptedMessage = [self encryptMessage:messageData forUsername:username iv:ivData];
    [messageForUsernames setObject:encryptedMessage forKey:username];
    
    [hmacData appendData:encryptedMessage];
    [hmacData appendData:ivData];
  }
  
  NSMutableData *tagData = [NSMutableData dataWithData:messageData];

  // for each username, compute the hmac
  for (NSString *username in usernames) {
    NSData *computedHmac = [self hmacFromData:hmacData forUsername:username];
    [hmacForUsernames setObject:computedHmac forKey:username];
    [tagData appendData:computedHmac];
  }
  
  NSData *tag = [self tagFromData:tagData];
  
  TBMultipartyChatMessage *mpcm = [[TBMultipartyChatMessage alloc] init];
  mpcm.senderName = self.myName;
  mpcm.usernames = usernames;
  mpcm.messageForUsernames = messageForUsernames;
  mpcm.ivForUsernames = ivForUsernames;
  mpcm.hmacForUsernames = hmacForUsernames;
  mpcm.tag = tag;
    
  return [mpcm toJSONString];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)decryptMessage:(NSString *)message
                fromUsername:(NSString *)username
                       error:(NSError **)error {
  TBMultipartyChatMessage *chatMessage = [[TBMultipartyChatMessage alloc]
                                          initWithJSONMessage:message senderName:username];
  
  // check HMAC
  if (![self checkHMACForChatMessage:chatMessage]) {
    if (error!=NULL) {
      *error = [NSError errorWithDomain:TBErrorDomainDecryption
                                   code:TBErrorCodeDecryptionIncorrectHMAC
                               userInfo:nil];
    }
    return nil;
  }
  
  // check IV reuse
  if (![self checkIVFirstUseForChatMessage:chatMessage]) {
    if (error!=NULL) {
      *error = [NSError errorWithDomain:TBErrorDomainDecryption
                                   code:TBErrorCodeDecryptionIncorrectIV
                               userInfo:nil];
    }
    return nil;
  }
  
  
  [self.usedIVs addObject:[chatMessage.ivForUsernames objectForKey:self.myName]];
  
  // get IV
  NSData *ivData = [chatMessage.ivForUsernames objectForKey:self.myName];
  
  NSData *cyphertextData = [chatMessage.messageForUsernames objectForKey:self.myName];
  NSMutableData *decryptedData = [NSMutableData dataWithData:
                                  [self encryptMessage:cyphertextData
                                           forUsername:username
                                                    iv:ivData]];
  
  // check tag
  if (![self checkTagForChatMessage:chatMessage decryptedData:decryptedData]) {
    if (error!=NULL) {
      *error = [NSError errorWithDomain:TBErrorDomainDecryption
                                   code:TBErrorCodeDecryptionIncorrectTag
                               userInfo:nil];
    }
    return nil;
  }
  
  // remove padding
  NSUInteger decryptedDataLength = decryptedData.length;
  [decryptedData setLength:decryptedDataLength-64];
  
  // compute the recipient that should have been sent this messages
  // all buddies in the chatroom
  NSMutableArray *computedRecipients = [[self.publicKeys allKeys] mutableCopy];
  [computedRecipients addObject:self.myName]; // don't forget to add myself
  [computedRecipients removeObject:username]; // don't include the sender of the message
  
  // check for missing recipients (but still return the decrypted string)
  NSArray *missingRecipients = [self checkForMissingRecipients:chatMessage
                                                     usernames:computedRecipients];
  
  // -- start debug
//  NSString *debug_decryptedMsg = [[NSString alloc] initWithData:decryptedData
//                                                       encoding:NSUTF8StringEncoding];
//  // simulate missing recipient
//  if ([debug_decryptedMsg isEqualToString:@"missingRecipients"]) {
//    missingRecipients = @[@"john", @"paul", @"george", @"joe", @"lou"];
//  }
//  
//  // simulate unreadable message
//  else if ([debug_decryptedMsg isEqualToString:@"unreadable"]) {
//    return nil;
//  }
  // -- end debug
  
  
  if ([missingRecipients count] > 0) {
    if (error!=NULL) {
      NSDictionary *userInfo = @{TBMDecryptionMissingRecipientsKey: missingRecipients};
      *error = [NSError errorWithDomain:TBErrorDomainDecryption
                                   code:TBErrorCodeDecryptionMissingRecipients
                               userInfo:userInfo];
    }
  }
  
  return [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)fingerprintForUsername:(NSString *)username {
  return [self.fingerprints objectForKey:username];
}


@end
