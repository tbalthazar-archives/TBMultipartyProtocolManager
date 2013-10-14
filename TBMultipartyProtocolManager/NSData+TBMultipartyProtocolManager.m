//
//  NSData+TBMultipartyProtocolManager.m
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 13/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//

#import "NSData+TBMultipartyProtocolManager.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation NSData (TBMultipartyProtocolManager)

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)tb_base64String {
  return [self base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSData *)tb_base64Data {
  return [self base64EncodedDataWithOptions:NSDataBase64Encoding64CharacterLineLength];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
+ (NSData *)tb_dataFromBase64String:(NSString *)base64String {
  return [[NSData alloc] initWithBase64EncodedString:base64String
                                              options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
+ (NSString *)tb_stringFromBase64Data:(NSData *)base64Data {
  NSData *decodedData = [[NSData alloc] initWithBase64EncodedData:base64Data options:NSDataBase64DecodingIgnoreUnknownCharacters];
  return [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
- (NSData *)tb_base64Decode {
  return [[NSData alloc] initWithBase64EncodedData:self
                                           options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

@end
