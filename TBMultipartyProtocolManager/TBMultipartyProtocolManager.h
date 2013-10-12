//
//  TBMultipartyProtocolManager.h
//  TBMultipartyProtocolManager
//
//  Created by Thomas Balthazar on 04/10/13.
//  Copyright (c) 2013 Thomas Balthazar. All rights reserved.
//

#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////
@interface TBMultipartyProtocolManager : NSObject

@property (nonatomic, readonly) NSString *privateKey;
@property (nonatomic, readonly) NSString *publicKey;
@property (nonatomic, strong) NSString *myName;

+ (TBMultipartyProtocolManager *)sharedMultipartyProtocolManager;

- (NSString *)publicKeyMessageForUsername:(NSString *)username;
- (BOOL)addPublicKeyFromMessage:(NSString *)publicKeyMessage forUsername:(NSString *)username;
- (NSString *)encryptMessage:(NSString *)message forUsername:(NSString *)username;
- (NSString *)decryptMessage:(NSString *)message fromUsername:(NSString *)username;

@end


/*
#include <stdio.h>
#define MAX_LINE 100

int main(void)
{
  char line[MAX_LINE];
  char *result;
  
  printf("Enter string:\n");
  if ((result = gets(line)) != NULL)
    printf("string is %s\n",result);
  else
    if (ferror(stdin))
      printf("Error\n");
}
*/