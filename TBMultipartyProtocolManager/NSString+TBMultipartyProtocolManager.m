//
//  NSString+TBMultipartyProtocolManager.m
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 07/10/13.
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
