//
//  TBMultipartyProtocolManager.m
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 04/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//

#import "TBMultipartyProtocolManager.h"
#import "NSString+TBMultipartyProtocolManager.h"
#import "TBMultipartyChatMessage.h"
#import <CommonCrypto/CommonDigest.h> // TODO: use OpenSSL instead of Apple's implementation

#import "curve25519-donna.h"
#import "aes.h"
#import "rand.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface TBMultipartyProtocolManager ()

@property (nonatomic, strong, readwrite) NSString *privateKey;
@property (nonatomic, strong, readwrite) NSString *publicKey;
@property (nonatomic, strong) NSMutableDictionary *publicKeys;
@property (nonatomic, strong) NSMutableDictionary *sharedSecrets;
@property (nonatomic, strong) NSMutableDictionary *fingerprints;

- (NSString *)generateSharedSecretForUsername:(NSString *)username;
- (NSString *)generateFingerprintForUsername:(NSString *)username;

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
    
    _privateKey = [privateKeyData
                   base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    _publicKey = [publicKeyData
                  base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    
    _publicKeys = [NSMutableDictionary dictionary];
    _sharedSecrets = [NSMutableDictionary dictionary];
    _fingerprints = [NSMutableDictionary dictionary];
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
  NSData *decodedPublicKey = [[NSData alloc] initWithBase64EncodedString:self.publicKey
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];
  NSData *decodedPrivateKey = [[NSData alloc] initWithBase64EncodedString:self.privateKey
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];
  
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
  
  //return [sharedSecretData base64EncodedString];
  return [sharedSecretData
          base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
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

    // -- start debug
    NSString *sharedSecret = [self.sharedSecrets objectForKey:username];
    //NSData *sharedSecretData = [sharedSecret dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *sharedSecretData = [[NSMutableData alloc]
                                       initWithBase64EncodedString:sharedSecret
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSLog(@"-- sharedSecretData length : %d", sharedSecretData.length);
    [sharedSecretData setLength:32];
    NSLog(@"-- sharedSecretData length : %d", sharedSecretData.length);
    
    NSLog(@"-- sharedSecretData for %@ :%@", username, sharedSecretData);
    NSLog(@"-- sharedSecretString for %@ : %@",
          username, [[NSString alloc] initWithData:sharedSecretData encoding:NSUTF8StringEncoding]);
   // -- end debug
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
  //memset(state->ivec + 8, 0, 8);
  memset(state->ivec + 12, 0, 4);
  /* Copy IV into 'ivec' */
  //memcpy(state->ivec, iv, 8);
  memcpy(state->ivec, iv, 12);
}


////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)encryptMessage:(NSString *)message forUsername:(NSString *)username {
  NSString *sharedSecret = [self.sharedSecrets objectForKey:username];
  const unsigned char* enc_key = (const unsigned char *)[sharedSecret
                                                         cStringUsingEncoding:NSUTF8StringEncoding];
  
  AES_KEY key;
  unsigned char indata[AES_BLOCK_SIZE];
  unsigned char outdata[AES_BLOCK_SIZE];
  unsigned char iv[AES_BLOCK_SIZE];
  struct ctr_state state;
  
  // create an IV with random bytes
  if(!RAND_bytes(iv, AES_BLOCK_SIZE)) {
    NSLog(@"-- error creating random bytes");
  }

  // Initializing the encryption KEY
  if (AES_set_encrypt_key(enc_key, 128, &key) < 0) {
    NSLog(@"-- error initializing private key");
  }

  // After we set our encryption key we need to initialize our state structure which holds our IV.
  init_ctr(&state, iv); // Counter call
  
  NSUInteger numberOfBytes = AES_BLOCK_SIZE;
  NSUInteger usedLength = 0;
  NSRange range = NSMakeRange(0, [message length]);
  
  
  /*
   when I read a short string (hello -> 5 bytes) in indata, I get something like :
   "Hello\x8a\xfa\xf3\x98\xdb\xff\xbf{]O\x02J9q4RotEZ6vagyln\xd5\xbc\xc7e\x87\xd3\xb3 \xdd\xe5\xc5A\xba\x9c\xa9/\xc0H\x19\xb4G\x9b\xaa\x94\x9a~o\xd5 \xe2\xc6\xfa\xed\xff\x81\x04\xaad+\x900\x1aDE\x10\xf8\x82\xbf\xe55\xc0\x1fOQ\xeb\x8f\x7fK\xaf\xcao\xb3-ux\x9d\xad\xd77\xccFXH\x87\xe9\x92'4\xc4\xe7\xecQ\xb5\xeb\xdb\x9d\xf3\xb3\x93\x1a\x1a!\xb4.\xde\xc6X\xdc\x84\xb6\x83Aw\x05\x10[m$\xa4u\xb3\xe2\xc0\x95\x19[C\xd4n^S\x8f\x03z\xf7\xfa\xb0\x98\x86\xfd4\xa7\xc5)Z\xf9\x96\xa6Y\x83a\\xe9\e)\x12~\x8f\xec;$vz\x9d}\xf5\e\xc1\x94\xee\x0e\xfcN\x02 u\x05\f"
   maybe I should read in a void *buffer and then convert it into the indata, so I don't have dummy
   stuff at the end?
   */
  BOOL bytesConversionOk = [message getBytes:indata
                                   maxLength:numberOfBytes
                                  usedLength:&usedLength
                                    encoding:NSUTF8StringEncoding
                                     options:0
                                       range:range
                              remainingRange:NULL];
//  while (bytesConversionOk && usedLength > 0) {
    /*
     After we read the bytes we then encrypt them using our AES_ctr128_encrypt function.
     This is the 128-bit encryption function found in aes.h.
     buffer is the data we read from the string.
     encrypted_buffer is our array to which the encrypted bytes will be placed.
     usedLength is the number of bytes in the indata array to be encrypted.
     Key is the encryption key that was set using our 16 byte password.
     State.ivec is the IV used for encryption.
     The last two variables are not used by us so we don’t need to know about them at all.
     */
    AES_ctr128_encrypt(indata, outdata, usedLength, &key, state.ivec, state.ecount, &state.num);
    
    // Now that we encrypted our data into outdata it’s time to write them to a file.
    //bytes_written = fwrite(outdata, 1, bytes_read, writeFile);
    //NSString *bufferString = [NSString stringWithUTF8String:buffer];
    //NSString *inData = [NSString stringWithUTF8String:(const char *)indata];
    NSString *inData = [[NSString alloc] initWithBytes:indata
                                                length:usedLength
                                              encoding:NSUTF8StringEncoding];
  
  
//    unsigned char outdata_for_nsstring[5];
//    strcpy(outdata_for_nsstring, outdata);
    NSString *outData = [[NSString alloc] initWithBytes:outdata
                                                 length:usedLength
                                               encoding:NSASCIIStringEncoding];

//    NSString *outData = [NSString stringWithUTF8String:(const char *)outdata];
    NSLog(@"-- unencrypted data (%d bytes) : %@", usedLength, inData);
    NSLog(@"-- encrypted outData : %@", outData);
//  }
  
  return outData;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)decryptMessage:(NSString *)message fromUsername:(NSString *)username {
  //Check HMAC
  //Check IV reuse
  //Decrypt
  //Check tag
  //Remove padding
  //Convert to UTF8
  
  
  TBMultipartyChatMessage *chatMessage = [[TBMultipartyChatMessage alloc]
                                          initWithJSONMessage:message];
  NSString *msgToDecrypt = [chatMessage.messageForUsernames objectForKey:self.myName];
  NSString *ivOjbect = [chatMessage.ivForUsernames objectForKey:self.myName];
  NSString *hmac = [chatMessage.hmacForUsernames objectForKey:self.myName];
  NSString *tag = chatMessage.tag;
  
  NSString *sharedSecret = [self.sharedSecrets objectForKey:username];
  //NSData *sharedSecretData = [sharedSecret dataUsingEncoding:NSUTF8StringEncoding];
  NSData *sharedSecretData = [[NSData alloc] initWithBase64EncodedString:sharedSecret
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];
  NSLog(@"-- sharedSecretData.length : %d", sharedSecretData.length);
  
//  const unsigned char* enc_key = (const unsigned char *)[sharedSecret
//                                                         cStringUsingEncoding:NSUTF8StringEncoding];
  unsigned char enc_key[32];
  [sharedSecretData getBytes:enc_key range:NSMakeRange(0, 32)];
  
  AES_KEY key;
  unsigned char indata[AES_BLOCK_SIZE];
  unsigned char outdata[AES_BLOCK_SIZE];
  unsigned char iv[12];
  struct ctr_state state;
  
  // IV
  NSData *ivData = [ivOjbect dataUsingEncoding:NSUTF8StringEncoding];
//  NSData *ivData = [[NSData alloc] initWithBase64EncodedString:ivOjbect
//                                              options:0];
  NSLog(@"-- ivData length : %d", ivData.length);
  //unsigned char* iv = (unsigned char *)[ivOjbect cStringUsingEncoding:NSUTF8StringEncoding];
  [ivData getBytes:iv range:NSMakeRange(0, 12)];
  
  // Initializing the encryption KEY
  if (AES_set_encrypt_key(enc_key, 256, &key) < 0) {
    NSLog(@"-- error initializing private key");
  }
  
  // After we set our encryption key we need to initialize our state structure which holds our IV.
  init_ctr(&state, iv); // Counter call

  // Decrypt the data in AES_BLOCK_SIZE bytes blocks
  NSData *encryptedData = [msgToDecrypt dataUsingEncoding:NSUTF8StringEncoding];
//  NSData *encryptedData = [[NSData alloc] initWithBase64EncodedString:msgToDecrypt
//                                              options:0];
  NSUInteger encryptedDataLength = encryptedData.length;
  NSUInteger byteRangeStart = 0;
  NSUInteger byteRangeLength = AES_BLOCK_SIZE;
  NSUInteger byteRangeMax = byteRangeStart + byteRangeLength;
  
  if (byteRangeMax > encryptedDataLength) {
    byteRangeLength = encryptedDataLength - byteRangeStart;
  }
  
  NSRange bytesRange = NSMakeRange(byteRangeStart, byteRangeLength);
  
  NSLog(@"-- will read %d bytes : %@", encryptedDataLength, encryptedData);
  
  NSMutableData *readData = [NSMutableData data]; // not needed, only for debug
  NSMutableData *decryptedData = [NSMutableData data];
  while (byteRangeStart < encryptedDataLength) {
    [encryptedData getBytes:indata range:bytesRange];
    AES_ctr128_encrypt(indata, outdata, byteRangeLength, &key, state.ivec, state.ecount, &state.num);
    [readData appendBytes:indata length:byteRangeLength];
    [decryptedData appendBytes:outdata length:byteRangeLength];
    
    byteRangeStart+=byteRangeLength;
    byteRangeMax = byteRangeStart + byteRangeLength;
    if (byteRangeMax > encryptedDataLength) {
      byteRangeLength = encryptedDataLength - byteRangeStart;
    }
    bytesRange = NSMakeRange(byteRangeStart, byteRangeLength);
  }
  
  NSLog(@"-- has read %d bytes : %@", readData.length, readData);
  
  NSLog(@"-- decrypted data has %d bytes : %@", decryptedData.length, decryptedData);
  
  // remove padding
  NSUInteger decryptedDataLength = decryptedData.length;
  NSLog(@"-- length before : %d", decryptedDataLength);
  [decryptedData setLength:decryptedDataLength-64];
  NSLog(@"-- length after : %d", decryptedData.length);

  //NSString *decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
  NSString *decryptedString = [decryptedData base64EncodedStringWithOptions:
                               NSDataBase64Encoding64CharacterLineLength];

  
  
  
//  [unencryptedData enumerateByteRangesUsingBlock:
//   ^(const void *bytes, NSRange byteRange, BOOL *stop) {
//    NSLog(@"RANGE %@", NSStringFromRange(byteRange));
//  }];
  
//enumerateByteRangesUsingBlock: ^(const void*bytes,NSRange range, BOOL*stop){
//  dispatch_async( {
//    /** Process the byte range */
//  }
//                 }
  
  /*
  NSUInteger numberOfBytes = AES_BLOCK_SIZE;
  NSUInteger usedLength = 0;
  NSRange range = NSMakeRange(0, [message length]);
  NSRange remainingRange;
  // --
  
  BOOL bytesConversionOk = [msgToDecrypt getBytes:indata
                                        maxLength:numberOfBytes
                                       usedLength:&usedLength
                                         encoding:NSUTF8StringEncoding
                                          options:0
                                            range:range
                                   remainingRange:&remainingRange];
  
  NSMutableData *decryptedData = [NSMutableData data];
  
  while (bytesConversionOk && usedLength > 0) {
//     After we read the bytes we then encrypt them using our AES_ctr128_encrypt function.
//     This is the 128-bit encryption function found in aes.h.
//     buffer is the data we read from the string.
//     encrypted_buffer is our array to which the encrypted bytes will be placed.
//     usedLength is the number of bytes in the indata array to be encrypted.
//     Key is the encryption key that was set using our 16 byte password.
//     State.ivec is the IV used for encryption.
//     The last two variables are not used by us so we don’t need to know about them at all.
    AES_ctr128_encrypt(indata, outdata, usedLength, &key, state.ivec, state.ecount, &state.num);
    NSLog(@"-- to decrypt indata : %s", indata);
    NSLog(@"-- decrypted outdata : %s", outdata);
    
    [decryptedData appendBytes:outdata length:numberOfBytes];
    
    bytesConversionOk = [msgToDecrypt getBytes:indata
                                     maxLength:numberOfBytes
                                    usedLength:&usedLength
                                      encoding:NSUTF8StringEncoding
                                       options:0
                                         range:remainingRange
                                remainingRange:&remainingRange];
    NSLog(@"-- remainingRange : %@", NSStringFromRange(remainingRange));
    
  }
  
  // remove padding
  NSUInteger decryptedDataLength = decryptedData.length;
  NSLog(@"-- length before : %d", decryptedDataLength);
  [decryptedData setLength:decryptedDataLength-64];
  NSLog(@"-- length after : %d", decryptedData.length);
  
  NSString *decryptedString = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];

  
  
  // Now that we encrypted our data into outdata it’s time to write them to a file.
  //bytes_written = fwrite(outdata, 1, bytes_read, writeFile);
  //NSString *bufferString = [NSString stringWithUTF8String:buffer];
  //NSString *inData = [NSString stringWithUTF8String:(const char *)indata];
  NSString *inData = [[NSString alloc] initWithBytes:indata
                                              length:usedLength
                                            encoding:NSUTF8StringEncoding];
  
  
  
  //    unsigned char outdata_for_nsstring[5];
  //    strcpy(outdata_for_nsstring, outdata);
  NSString *outData = [[NSString alloc] initWithBytes:outdata
                                               length:usedLength
                                             encoding:NSUTF8StringEncoding];
  
  //    NSString *outData = [NSString stringWithUTF8String:(const char *)outdata];
  NSLog(@"-- unencrypted data (%d bytes) : %@", usedLength, inData);
  NSLog(@"-- encrypted outData : %@", outData);
*/
  
  return nil;
}


@end
