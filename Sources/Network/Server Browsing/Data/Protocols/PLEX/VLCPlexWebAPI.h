/*****************************************************************************
 * VLCPlexWebAPI.h
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2014-2019 VideoLAN. All rights reserved.
 *
 * Authors: Pierre Sagaspe <pierre.sagaspe # me.com>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import <UIKit/UIKit.h>
@interface VLCPlexWebAPI : NSObject

- (NSMutableDictionary *)PlexBasicAuthentification:(NSString *)username password:(NSString *)password;
- (NSString *)PlexAuthentification:(NSString *)username password:(NSString *)password;
- (NSString *)urlAuth:(NSString *)url authentification:(NSString *)auth;
- (void)stopSession:(NSString *)address port:(NSString *)port session:(NSString *)session;
- (NSInteger)MarkWatchedUnwatchedMedia:(NSString *)address port:(NSString *)port videoRatingKey:(NSString *)ratingKey state:(NSString *)state authentification:(NSString *)auth;
- (NSString *)getFileSubtitleFromPlexServer:(NSDictionary *)mediaObject modeStream:(BOOL)modeStream error:(NSError *__autoreleasing*)error;
- (NSString *)getSession;

+ (NSString *)urlAuth:(NSString *)url authentification:(NSString *)auth;

@end
