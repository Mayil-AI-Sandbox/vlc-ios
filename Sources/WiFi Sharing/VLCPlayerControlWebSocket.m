/*****************************************************************************
 * VLCPlayerControlWebSocket.m
 * VLC for iOS
 *****************************************************************************
 * Copyright (c) 2015 VideoLAN. All rights reserved.
 * $Id$
 *
 * Authors: Felix Paul Kühne <fkuehne # videolan.org>
 *
 * Refer to the COPYING file of the official project for license.
 *****************************************************************************/

#import "VLCPlayerControlWebSocket.h"
#import "VLCMetadata.h"

@implementation VLCPlayerControlWebSocket

- (void)didOpen
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(playbackStarted)
                               name:VLCPlaybackServicePlaybackDidStart
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(playbackStarted)
                               name:VLCPlaybackServicePlaybackDidResume
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(_respondToPlaying)
                               name:VLCPlaybackServicePlaybackMetadataDidChange
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(playbackPaused)
                               name:VLCPlaybackServicePlaybackDidPause
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(playbackEnded)
                               name:VLCPlaybackServicePlaybackDidStop
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(playbackEnded)
                               name:VLCPlaybackServicePlaybackDidFail
                             object:nil];
    [notificationCenter addObserver:self
                           selector:@selector(playbackSeekTo)
                               name:VLCPlaybackServicePlaybackPositionUpdated
                             object:nil];

    APLog(@"web socket did open");

    [super didOpen];
}

- (void)didReceiveMessage:(NSString *)msg
{
    NSError *error;
    NSDictionary *receivedDict = [NSJSONSerialization JSONObjectWithData:[msg dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingAllowFragments error:&error];

    if (error != nil) {
        APLog(@"JSON deserialization failed for %@", msg);
        return;
    }

    NSString *type = receivedDict[@"type"];
    if (!type) {
        APLog(@"No type in received JSON dict %@", receivedDict);
    }

    if ([type isEqualToString:@"playing"]) {
        [self _respondToPlaying];
    } else if ([type isEqualToString:@"play"]) {
        [self _respondToPlay];
    } else if ([type isEqualToString:@"pause"]) {
        [self _respondToPause];
    } else if ([type isEqualToString:@"ended"]) {
        [self _respondToEnded];
    } else if ([type isEqualToString:@"seekTo"]) {
        [self _respondToSeek:receivedDict];
    } else if ([type isEqualToString:@"openURL"]) {
        [self performSelectorOnMainThread:@selector(_respondToOpenURL:) withObject:receivedDict waitUntilDone:NO];
    } else if ([type isEqualToString:@"volume"]) {
        [self sendMessage:@"VOLUME CONTROL NOT SUPPORTED ON THIS DEVICE"];
    } else
        [self sendMessage:@"INVALID REQUEST!"];
}

#ifndef NDEBUG
- (void)didClose
{
    APLog(@"web socket did close");

    [super didClose];
}
#endif

- (void)_respondToPlaying
{
    /* JSON response
     {
        "type": "playing",
        "currentTime": 42,
        "media": {
            "id": "some id",
            "title": "some title",
            "duration": 120000
        }
     }
     */

    VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];
    NSDictionary *returnDict;

    if (vpc.isPlaying) {
        VLCMedia *media = [vpc currentlyPlayingMedia];

        if (media) {
            NSURL *url = media.url;
            NSString *mediaTitle = vpc.metadata.title;
            if (!mediaTitle) {
                mediaTitle = url.lastPathComponent;
            }
            NSDictionary *mediaDict = @{ @"id" : url.absoluteString,
                                         @"title" : mediaTitle,
                                         @"duration" : @([vpc mediaDuration])};
            returnDict = @{ @"currentTime" : @([vpc playedTime].intValue),
                            @"type" : @"playing",
                            @"media" : mediaDict };
        }
    }
    if (!returnDict) {
        returnDict = [NSDictionary dictionary];
    }
    [self sendDataWithDict:returnDict];
}

#pragma mark - play

- (void)_respondToPlay
{
    VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];
    [vpc play];
}

- (void)playbackStarted
{
    /*
     {
        "type": "play",
        "currentTime": 42
     }
     */
     VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];
    NSDictionary *dict = @{ @"currentTime" : @([vpc playedTime].intValue),
                                  @"type" : @"play" };
    [self sendDataWithDict:dict];

}

#pragma mark - pause

- (void)_respondToPause
{
    VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];
    [vpc pause];
}

- (void)playbackPaused
{
    /*
     {
        "type": "pause",
        "currentTime": 42,
     }
     */
     VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];
    NSDictionary *dict = @{ @"currentTime" : @([vpc playedTime].intValue),
                            @"type" : @"pause" };
    [self sendDataWithDict:dict];
}

- (void)sendDataWithDict:(NSDictionary *)dict
{
    VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];

    VLCMedia *media = [vpc currentlyPlayingMedia];
    if (media) {
        NSError *error;
        NSData *returnData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        if (error != nil) {
            APLog(@"%s: JSON serialization failed %@", __PRETTY_FUNCTION__, error);
        }

        [self sendData:returnData];
    }
}

#pragma mark - ended

- (void)_respondToEnded
{
    VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];
    [vpc stopPlayback];
}

- (void)playbackEnded
{
    /*
     {
        "type": "ended"
     }
     */
    NSDictionary *dict = @{ @"type" : @"ended" };
    [self sendDataWithDict:dict];
}

#pragma mark - seek

- (void)_respondToSeek:(NSDictionary *)dictionary
{
    /*
     {
        "currentTime" = 12514;
        "type" = seekTo;
     }
     */
    VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];

    VLCMedia *media = [vpc currentlyPlayingMedia];
    if (!media)
        return;

    vpc.playbackPosition = [dictionary[@"currentTime"] floatValue] / (CGFloat)media.length.intValue;
}

- (void)playbackSeekTo
{
    /* 
     {
        "type": "seekTo",
        "currentTime": 42,
        "media": {
            "id": 42
        }
     }
     */

    VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];
    VLCMedia *media = [vpc currentlyPlayingMedia];
    if (!media) {
        return;
    }
    NSDictionary *mediaDict = @{ @"id" : media.url.absoluteString};
    NSDictionary *dict = @{ @"currentTime" : @([vpc playedTime].intValue),
                                  @"type" : @"seekTo",
                                  @"media" : mediaDict };
    [self sendDataWithDict:dict];
}

#pragma mark - openURL
- (void)_respondToOpenURL:(NSDictionary *)dictionary
{
    /*
     {
        "type": "OpenURL",
        "url": "https://vimeo.com/74370512"
     }
     */
    VLCPlaybackService *vpc = [VLCPlaybackService sharedInstance];
    VLCMediaList *mediaList = vpc.mediaList;
    if (!mediaList) {
        mediaList = [[VLCMediaList alloc] init];
    }

    NSString *urlString = dictionary[@"url"];
    if (urlString == nil || urlString.length == 0)
        return;

    /* force store update */
    NSUbiquitousKeyValueStore *ubiquitousKeyValueStore = [NSUbiquitousKeyValueStore defaultStore];
    [ubiquitousKeyValueStore synchronize];

    /* fetch data from cloud */
    NSMutableArray *recentURLs = [NSMutableArray arrayWithArray:[ubiquitousKeyValueStore arrayForKey:kVLCRecentURLs]];

    /* re-order array and add item */
    if ([recentURLs indexOfObject:urlString] != NSNotFound)
        [recentURLs removeObject:urlString];

    if (recentURLs.count >= 100)
        [recentURLs removeLastObject];
    [recentURLs addObject:urlString];

    /* sync back */
    [ubiquitousKeyValueStore setArray:recentURLs forKey:kVLCRecentURLs];

    VLCMedia *receivedMedia = [VLCMedia mediaWithURL:[NSURL URLWithString:urlString]];
    [mediaList addMedia:receivedMedia];
    NSInteger indexToPlay = [mediaList indexOfMedia:receivedMedia];
    if (!vpc.isPlaying) {
        [vpc playMediaList:mediaList firstIndex:indexToPlay subtitlesFilePath:nil];
    }
}

@end
