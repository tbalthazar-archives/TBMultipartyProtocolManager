//
//  NSString+TBMultipartyProtocolManager.m
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 07/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//

#import "NSString+TBMultipartyProtocolManager.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation NSString (TBMultipartyProtocolManager)

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark JSON

////////////////////////////////////////////////////////////////////////////////////////////////////
+ (NSString *)tb_stringFromJSONObject:(id)JSONObject {
  if (![NSJSONSerialization isValidJSONObject:JSONObject]) return nil;
  
  NSError *error;
  NSData *JSONData = [NSJSONSerialization dataWithJSONObject:JSONObject options:0 error:&error];
  if (error!=nil) return nil;
  
  return [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
}

////////////////////////////////////////////////////////////////////////////////////////////////////
+ (NSDictionary *)tb_JSONStringToDictionary:(NSString *)JSONString {
  NSData *JSONData = [JSONString dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:JSONData
                                                             options:0
                                                               error:&error];
  if (error!=nil) return nil;
  
  return dictionary;
}

@end
