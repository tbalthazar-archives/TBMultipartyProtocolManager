//
//  NSData+TBMultipartyProtocolManager.h
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 13/10/13.
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
//  along with Cryptocat for iOS.  If not, see <http://www.gnu.org/licenses/>.
//

#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface NSData (TBMultipartyProtocolManager)

// encode : convert non base64 to base64
- (NSString *)tb_base64String;

// decode : convert base64 to non-base64
+ (NSData *)tb_dataFromBase64String:(NSString *)base64String;

@end
