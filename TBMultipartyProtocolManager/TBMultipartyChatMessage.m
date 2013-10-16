//
//  TBMultipartyChatMessage.m
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 11/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//

#import "TBMultipartyChatMessage.h"
#import "NSString+TBMultipartyProtocolManager.h"
#import "NSData+TBMultipartyProtocolManager.h"

/*
{
  "text":{
    "iOSTestApp":{
      "message":"92pVlWIP/KCZ8d92HPThAyfcGCuHHzVdnbPSve3OioiqIu0EeRpabviPuEY3vpcl1wQx0OrGi6tRTNPCpFQpF1pfj4fZEV98P3fvDw==",
      "iv":"eJ5ig+30g7ih/Q+C",
      "hmac":"ILY4oQrJ0YOVaSQgR+c4dSGr9Q1gRL4UVF1tmQ0KV8mckGH8vGl683Fnny/zZHCEJDuI7BpCBtbRM+opH4JUBg=="
    },
    "roger":{
      "message":"tYXE0Fkmimcoiu8bTVxn624aGJySHEFIgu8zNtcJncldkSoye4SDHP5O8ZqQDAX7qCF4m3PU/u68Eut/4jblxfiDwz+pd0XArHTONg==",
      "iv":"usWG1RkA4oI6ZVdX",
      "hmac":"zn7YlTgyjy5ovJNFvQSNTDDUCYlBVyAhOrxJ25Ge43LgFMD3aApxGjaCjd6vWUqqHLezpQejrO1xyD5u9bgGoA=="
    }
  },
  "type":"message",
  "tag":"08NQ7t8Rl9LPr2tIIs/N+YhyfXiTARqNEKQjFbz2o7nnJXOL3Ji3CsBmgTDwwjXRkYWVP6yrJPMjibkz8JNyFA=="
}
*/

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation TBMultipartyChatMessage

////////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithJSONMessage:(NSString *)JSONMessage senderName:(NSString *)senderName {
  //  All the binary data (ciphertexts, IVs and HMACs) is encoded as Base64 when sending
  if (self=[super init]) {
    _senderName = senderName;
    
    NSDictionary *JSONDic = [NSString tb_JSONStringToDictionary:JSONMessage];
    
    // usernames
    NSArray *unsortedUsernames = [[JSONDic objectForKey:@"text"] allKeys];
    _usernames = [unsortedUsernames
                  sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
    NSUInteger nbUsernames = [_usernames count];
    
    // messages
    NSMutableDictionary *messageForUsernames = [NSMutableDictionary
                                                dictionaryWithCapacity:nbUsernames];
    for (NSString *username in _usernames) {
      NSString *message = [[[JSONDic objectForKey:@"text"]
                            objectForKey:username] objectForKey:@"message"];
      NSData *messageData = [[NSData alloc] initWithBase64EncodedString:message
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];
      [messageForUsernames setObject:messageData forKey:username];
    }
    _messageForUsernames = messageForUsernames;
    
    // iv
    NSMutableDictionary *ivForUsernames = [NSMutableDictionary dictionaryWithCapacity:nbUsernames];
    for (NSString *username in _usernames) {
      NSString *iv = [[[JSONDic objectForKey:@"text"] objectForKey:username] objectForKey:@"iv"];
      NSData *ivData = [[NSData alloc] initWithBase64EncodedString:iv
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];
      [ivForUsernames setObject:ivData forKey:username];
    }
    _ivForUsernames = ivForUsernames;
    
    // hmac
    NSMutableDictionary *hmacForUsernames = [NSMutableDictionary
                                             dictionaryWithCapacity:nbUsernames];
    for (NSString *username in _usernames) {
      NSString *hmac = [[[JSONDic objectForKey:@"text"]
                         objectForKey:username] objectForKey:@"hmac"];
      NSData *hmacData = [[NSData alloc] initWithBase64EncodedString:hmac
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];
      [hmacForUsernames setObject:hmacData forKey:username];
    }
    _hmacForUsernames = hmacForUsernames;
    
    // tag
    _tag = [[NSData alloc] initWithBase64EncodedString:[JSONDic objectForKey:@"tag"]
                                               options:NSDataBase64DecodingIgnoreUnknownCharacters];
  }
  
  return self;
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)toJSONString {
  NSMutableDictionary *usersDic = [NSMutableDictionary
                                   dictionaryWithCapacity:[self.usernames count]];
  for (NSString *username in self.usernames) {
    NSString *message = [[self.messageForUsernames objectForKey:username] tb_base64String];
    NSString *iv = [[self.ivForUsernames objectForKey:username] tb_base64String];
    NSString *hmac = [[self.hmacForUsernames objectForKey:username] tb_base64String];
    
    [usersDic setObject:@{@"message": message, @"iv": iv, @"hmac": hmac}
                 forKey:username];
  }
  
  NSString *tag = [self.tag tb_base64String];
  NSDictionary *messageDic =  @{  @"text": usersDic,
                                  @"type": @"message",
                                  @"tag": tag};
  
  return [NSString tb_stringFromJSONObject:messageDic];
}

@end
