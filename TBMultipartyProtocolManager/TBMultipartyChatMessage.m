//
//  TBMultipartyChatMessage.m
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 11/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//

#import "TBMultipartyChatMessage.h"
#import "NSString+TBMultipartyProtocolManager.h"

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
- (id)initWithJSONMessage:(NSString *)JSONMessage {
  //  All the binary data (ciphertexts, IVs and HMACs) is encoded as Base64 when sending
  if (self=[super init]) {
    NSDictionary *JSONDic = [NSString tb_JSONStringToDictionary:JSONMessage];
    
    // usernames
    _usernames = [[JSONDic objectForKey:@"text"] allKeys];
    NSUInteger nbUsernames = [_usernames count];
    
    // messages
    NSMutableDictionary *messageForUsernames = [NSMutableDictionary
                                                dictionaryWithCapacity:nbUsernames];
    for (NSString *username in _usernames) {
      NSString *message = [[[JSONDic objectForKey:@"text"]
                            objectForKey:username] objectForKey:@"message"];
      //message = [NSString tb_stringFromBase64String:message];
      [messageForUsernames setObject:message forKey:username];
    }
    _messageForUsernames = messageForUsernames;
    
    // iv
    NSMutableDictionary *ivForUsernames = [NSMutableDictionary dictionaryWithCapacity:nbUsernames];
    for (NSString *username in _usernames) {
      NSString *iv = [[[JSONDic objectForKey:@"text"] objectForKey:username] objectForKey:@"iv"];
      //iv = [NSString tb_stringFromBase64String:iv];
      [ivForUsernames setObject:iv forKey:username];
    }
    _ivForUsernames = ivForUsernames;
    
    // hmac
    NSMutableDictionary *hmacForUsernames = [NSMutableDictionary
                                             dictionaryWithCapacity:nbUsernames];
    for (NSString *username in _usernames) {
      NSString *hmac = [[[JSONDic objectForKey:@"text"]
                         objectForKey:username] objectForKey:@"hmac"];
      //hmac = [NSString tb_stringFromBase64String:hmac];
      [hmacForUsernames setObject:hmac forKey:username];
    }
    _hmacForUsernames = hmacForUsernames;
    
    // tag
    _tag = [JSONDic objectForKey:@"tag"];
  }
  
  return self;
}

@end
