//
//  AudioUnitManager.m
//  TXLiteAVDemo_Professional
//
//  Created by einhorn on 2024/1/8.
//  Copyright © 2024 Tencent. All rights reserved.
//

#import "AudioUnitManager.h"
class AudioUnitWrapper {
    
    
public:
    void ResetMuteState(){
        AudioUnit audio_unit = CreateAudioUnit(kAudioUnitSubType_VoiceProcessingIO);
           AudioUnitInitialize(audio_unit);

            const UInt32 mute = 0;
            auto call_result = AudioUnitSetProperty(audio_unit,
                                                    kAUVoiceIOProperty_MuteOutput,
                                                    kAudioUnitScope_Global,
                                                    1,
                                                    &mute,
                                                    sizeof(mute));

            AudioUnitUninitialize(audio_unit);
            AudioComponentInstanceDispose(audio_unit);
    }
    AudioUnit CreateAudioUnit(OSType audioUnitSubType) {
        // 设置AudioComponentDescription
        AudioComponentDescription desc;
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = audioUnitSubType;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        desc.componentFlags = 0;
        desc.componentFlagsMask = 0;

        // 查找AudioComponent
        AudioComponent comp = AudioComponentFindNext(NULL, &desc);
        if (comp == NULL) {
            //*outStatus = kAudioUnitErr_FormatNotSupported;
            return NULL;
        }

        // 创建AudioUnit实例
        AudioUnit audioUnit;
        OSStatus outStatus = AudioComponentInstanceNew(comp, &audioUnit);
        if (outStatus != noErr) {
            return NULL;
        }

        // 返回AudioUnit实例
        return audioUnit;
    }
    
};
@implementation AudioUnitManager
+(void) ResetMuteState {
    AudioUnitWrapper* wrapper = new AudioUnitWrapper ();
    wrapper->ResetMuteState();
}
@end
