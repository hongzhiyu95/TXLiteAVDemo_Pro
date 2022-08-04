//
//  AVReader.m
//  TXXiaoshipin
//
//  Created by taopu-iMac on 16/12/1.
//  Copyright © 2016年 qqcloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "iLiveMVReader.h"


@implementation iLiveMVReader
{
    AVAsset                  * avAsset;
    AVAssetTrack             * videoTrack;
    AVAssetTrack             * audioTrack;
    AVAssetImageGenerator    * generate;
    
    NSMutableArray           * videoTracks;
    NSMutableArray           * videoAssets;
    NSMutableArray           * startVideoTimeArray;
    
    NSMutableArray           * audioTracks;
    NSMutableArray           * audioAssets;
    NSMutableArray           * startAudioTimeArray;
    
    NSInteger                _index;

    int                      _audioSampleRate;
    BOOL                     _resetVideoReader;
    BOOL                     _resetAudioReader;
    float                    _videoTime;
    float                    _audioTime;
    
    VideoReadFormat          _videoFormat;
    
    /// 非线程安全，为了解决AVComposition泄漏的问题
    /// @ref https://stackoverflow.com/questions/48806361/avmutablecomposition-memory-leak
    AVMutableComposition     *_sharedComposition;
}

- (instancetype) initWithMP4PathAsset:(NSObject *)pathAsset videoReadFormat:(VideoReadFormat)videoReadFormat
{
    self = [super init];
    if (self) {
        _videoCanRead = YES;
        _audioCanRead = YES;
        _hasAudioData = NO;
        _videoCutType = VideoCutType_None;
        _videoFormat  = videoReadFormat;
        if ([pathAsset isKindOfClass:[NSString class]]) {
            [self initAVReaderWithPath:(NSString *)pathAsset];
        }else{
            [self initAVReaderWithAsset:(AVAsset *)pathAsset];
        }
        [self initVideoReader];
        [self initAudioReader];
    }
    return self;
}


- (void) initAVReaderWithPath:(NSString *)path
{
    NSURL *avUrl = [NSURL fileURLWithPath:path];
    avAsset = [AVAsset assetWithURL:avUrl];
    _duration = avAsset.duration;
}

- (void) initAVReaderWithAsset:(AVAsset *)asset
{
    avAsset = asset;
    _duration = avAsset.duration;
}

- (void) initVideoReader
{
   //获取视频的总轨道
    videoTrack = [[avAsset tracksWithMediaType:AVMediaTypeVideo] lastObject];
    
    if (videoTrack == nil) {
        return;
    }
    
    _fps = [videoTrack nominalFrameRate];
    
    _bitrate = [videoTrack estimatedDataRate] / 1000;
    
    _width = [videoTrack naturalSize].width;
    
    _height = [videoTrack naturalSize].height;
    
    _totalSampleDataLength = videoTrack.totalSampleDataLength;
    
    CGAffineTransform txf       = [videoTrack preferredTransform];
    _angle  = RadiansToDegrees(atan2(txf.b, txf.a));
}

static inline CGFloat RadiansToDegrees(CGFloat radians) {
    return radians * 180 / M_PI;
};


- (void) initAudioReader
{
    //获取音频的总轨道
    audioTrack = [[avAsset tracksWithMediaType:AVMediaTypeAudio] lastObject];
    
    if (audioTrack == nil) {
        _hasAudioData = NO;
        return;
    }
    _hasAudioData = YES;
    
    NSArray * audioFMT = audioTrack.formatDescriptions;
    
    _audioSampleRate    = 44100;
    _audioChannels      = 1;
    _audioBytesPerFrame = 2;
    
    if(audioFMT != nil && audioFMT.count > 0) {
        CMAudioFormatDescriptionRef fmtDesc = (__bridge CMAudioFormatDescriptionRef)[audioFMT objectAtIndex:0];
        
        if(fmtDesc != nil) {
            const AudioStreamBasicDescription * audioDesc =  CMAudioFormatDescriptionGetStreamBasicDescription(fmtDesc);
            
            if(audioDesc != nil) {
                _audioSampleRate    = audioDesc->mSampleRate;
                _audioChannels      = audioDesc->mChannelsPerFrame;
                if(audioDesc->mBytesPerFrame != 0) _audioBytesPerFrame = audioDesc->mBytesPerFrame;
                else _audioBytesPerFrame = 2 * _audioChannels;
            }
        }
    }
}

/// 非线程安全，目前所有用到的地方都在@synchronized(self)中
- (AVMutableComposition *)sharedAVMutableComposition {
    if (nil == _sharedComposition) {
        _sharedComposition = [[AVMutableComposition alloc] init];
    }
    NSArray *tracks = _sharedComposition.tracks;
    for (AVCompositionTrack *track in tracks) {
        [_sharedComposition removeTrack:track];
    }
    return _sharedComposition;
}

//截取 startTime -> endTime 的视频轨道
- (void) cutVideoFromTime:(float)startTime toTime:(float)endTime
{
    @synchronized (self) {
        _videoCutType = VideoCutType_Duration;
        
        startVideoTimeArray = [NSMutableArray array];
        
        CMTime videoStartTime = CMTimeMake(startTime * _duration.timescale, _duration.timescale);
        CMTimeRange timeRange = CMTimeRangeMake(videoStartTime, CMTimeMakeWithSeconds(endTime - startTime,_duration.timescale));
        
        [startVideoTimeArray addObject:[NSValue valueWithCMTime:videoStartTime]];
        
        videoTracks = [NSMutableArray array];
        videoAssets = [NSMutableArray array];
        
        AVMutableComposition *subAsset = [self sharedAVMutableComposition];// [[AVMutableComposition alloc]init];
        AVMutableCompositionTrack *subTrack = [subAsset addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
        [subTrack  insertTimeRange:timeRange ofTrack:videoTrack atTime:videoStartTime error:nil];
        AVAsset *assetNew = [subAsset copy];
        AVAssetTrack *assetTrackNew = [[assetNew tracksWithMediaType:AVMediaTypeVideo] lastObject];
        [videoTracks addObject:assetTrackNew];
        [videoAssets addObject:assetNew];
    }
}

//截取 startTime -> endTime 的音频轨道
- (void) cutAudioFromTime:(float)startTime toTime:(float)endTime
{
    @synchronized (self) {
        startAudioTimeArray = [NSMutableArray array];
        
        CMTime videoStartTime = CMTimeMake(startTime * _duration.timescale, _duration.timescale);
        CMTimeRange timeRange = CMTimeRangeMake(videoStartTime, CMTimeMakeWithSeconds(endTime - startTime,_duration.timescale));
        
        [startAudioTimeArray addObject:[NSValue valueWithCMTime:videoStartTime]];
        
        audioTracks = [NSMutableArray array];
        audioAssets = [NSMutableArray array];
        
        AVMutableComposition *subAsset = [self sharedAVMutableComposition];//[[AVMutableComposition alloc]init];
        AVMutableCompositionTrack *subTrack =   [subAsset addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
        [subTrack  insertTimeRange:timeRange ofTrack:audioTrack atTime:videoStartTime error:nil];
        AVAsset *assetNew = [subAsset copy];
        AVAssetTrack *assetTrackNew = [[assetNew tracksWithMediaType:AVMediaTypeAudio] lastObject];
        [audioTracks addObject:assetTrackNew];
        [audioAssets addObject:assetNew];
    }
}


- (NSInteger)findFrameIndex:(float)time isVideo:(BOOL)isVideo
{
    NSInteger index = 0;
    if (isVideo) {
        for (NSValue *startTime in startVideoTimeArray) {
            CMTime cmTime = [startTime CMTimeValue];
            if ((float)cmTime.value / cmTime.timescale >= time + 1.0 / _fps) {
                break;
            }
            index ++;
        }
    }else{
        for (NSValue *startTime in startAudioTimeArray) {
            CMTime cmTime = [startTime CMTimeValue];
            if ((float)cmTime.value / cmTime.timescale >= time + 1.0 / _fps) {
                break;
            }
            index ++;
        }
    }
    if (index >= 1) {
        index = index - 1;
    }
    return index;
}

- (AVAssetReaderOutput *)getTrackOutput:(NSInteger)index isVideo:(BOOL)isVideo
{
    AVAssetReaderOutput *trackOutput = nil;
    if (isVideo) {
        NSDictionary *settingV;
        if (_videoFormat == VideoReadFormat_BGRA) {
            settingV = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey, nil];
        }else{
            settingV = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange], kCVPixelBufferPixelFormatTypeKey, nil];
        }
        
        if (index >= 0 && index < videoTracks.count) {
             trackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTracks[index] outputSettings:settingV];
        }
    }else{
        NSDictionary *settingA =   @{(id)AVFormatIDKey:@(kAudioFormatLinearPCM)};
        if (index >= 0 && index < audioTracks.count) {
            trackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:audioTracks[index] outputSettings:settingA];
        }
    }
    return trackOutput;
}

- (AVAssetReader *) getAssetReader:(NSInteger)index isVideo:(BOOL)isVideo trackOutput:(AVAssetReaderOutput *)trackOutput
{
    
    NSError *error = nil;
    AVAssetReader *reader = nil;
    if (isVideo) {
        if (videoAssets != nil && ![videoAssets isKindOfClass:[NSNull class]] && videoAssets.count != 0 && index >= 0 && index < videoAssets.count) {
             reader = [[AVAssetReader alloc] initWithAsset:videoAssets[index] error:&error];
        }
    }else{
        if (audioAssets != nil && ![audioAssets isKindOfClass:[NSNull class]] && audioAssets.count != 0 && index >= 0 && index < audioAssets.count) {
            reader = [[AVAssetReader alloc] initWithAsset:audioAssets[index] error:&error];
        }
    }
    
    if(trackOutput != nil && [reader canAddOutput:trackOutput]){
        [reader addOutput:trackOutput];
    }else{
        reader = nil;
    }
    return  reader;
}

- (void) readVideoFrameFromTime:(float)startTime
                         toTime:(float)endTime
                   readOneFrame:(readOneFrame)readOneFrame
                   readFinished:(readFinished)readFinished
{
    @autoreleasepool {
        [self cutVideoFromTime:startTime toTime:endTime];
        AVAssetReaderOutput *trackOutput = [self getTrackOutput:0 isVideo:YES];
        AVAssetReader *reader = [self getAssetReader:0 isVideo:YES trackOutput:trackOutput];
        if(trackOutput == nil || reader == nil || !_videoCanRead) return;
        [reader startReading];
        CMSampleBufferRef sample = [trackOutput copyNextSampleBuffer];
        CMTime time = kCMTimeZero;
        while(sample != nil && CMSampleBufferIsValid(sample)) {
            if (!_videoCanRead){
                CFRelease(sample);
                [reader cancelReading];
                return;
            }
            time = CMSampleBufferGetPresentationTimeStamp(sample);
            float pts = (float)time.value / time.timescale;
            if (pts >= startTime && pts <= endTime){
                readOneFrame(sample);
            }else{
                CFRelease(sample);
            }
            if (_resetVideoReader) {
                [self cutVideoFromTime:(int)pts toTime:endTime];
                startTime = pts;
                trackOutput = [self getTrackOutput:0 isVideo:YES];
                [reader cancelReading];
                reader = [self getAssetReader:0 isVideo:YES trackOutput:trackOutput];
                [reader startReading];
                _resetVideoReader = NO;
            }
            sample = [trackOutput copyNextSampleBuffer];
        }
        [reader cancelReading];
        
        if(_videoCanRead) readFinished();
    }
}

- (void) readAudioFrameFromTime:(float)startTime
                         toTime:(float)endTime
                   readOneFrame:(readOneFrame)readOneFrame
                   readFinished:(readFinished)readFinished
{
    @autoreleasepool {
        [self cutAudioFromTime:startTime toTime:endTime];
        AVAssetReaderOutput *trackOutput = [self getTrackOutput:0 isVideo:NO];
        AVAssetReader *reader = [self getAssetReader:0 isVideo:NO trackOutput:trackOutput];
        if(trackOutput == nil || reader == nil || !_audioCanRead) return;
        [reader startReading];
        CMSampleBufferRef sample = [trackOutput copyNextSampleBuffer];
        CMTime time = kCMTimeZero;
        while(sample != nil) {
            if (!_audioCanRead){
                CFRelease(sample);
                [reader cancelReading];
                return;
            }
            time = CMSampleBufferGetPresentationTimeStamp(sample);
            float pts = (float)time.value / time.timescale;
            if (pts >= startTime){
                readOneFrame(sample);
            }else{
                CFRelease(sample);
            }
            if (_resetAudioReader) {
                [self cutAudioFromTime:(int)pts toTime:endTime];
                startTime = pts;
                trackOutput = [self getTrackOutput:0 isVideo:NO];
                [reader cancelReading];
                reader = [self getAssetReader:0 isVideo:NO trackOutput:trackOutput];
                [reader startReading];
                _resetAudioReader = NO;
            }
            sample = [trackOutput copyNextSampleBuffer];
        }
        [reader cancelReading];
        if(_audioCanRead) readFinished();
    }
}

- (void) startVideoRead
{
    _videoCanRead = YES;
}

- (void) stopVideoRead
{
    _videoCanRead = NO;
}

- (void) startAudioRead
{
    _audioCanRead = YES;
}

- (void) stopAudioRead
{
    _audioCanRead = NO;
}

- (void) resetVideoReader
{
    _resetVideoReader = YES;
}

- (void) resetAudioReader
{
    _resetAudioReader = YES;
}

- (AVAssetImageGenerator *)imageGenerator {
    @synchronized(self) {
        if (generate == nil) {
            generate = [[AVAssetImageGenerator alloc] initWithAsset:avAsset];
            generate.appliesPreferredTrackTransform= YES;
            generate.requestedTimeToleranceAfter = kCMTimeZero;
            generate.requestedTimeToleranceBefore = kCMTimeZero;
        }
    }
    return generate;
}

@end
