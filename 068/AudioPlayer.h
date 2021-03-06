// 「レシピ068: AudioQueueで再生する」のサンプルコード (P.158)

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioFile.h>

#define NUM_BUFFERS 3

@interface AudioPlayer : NSObject {
    AudioFileID audioFile;
    AudioStreamBasicDescription dataFormat;
    AudioQueueRef queue;
    SInt64 packetIndex;
    UInt32 numPacketsToRead;
    UInt32 bufferByteSize;
    AudioStreamPacketDescription *packetDescs;
    AudioQueueBufferRef buffers[NUM_BUFFERS];
}

@property AudioQueueRef queue;

- (void) play:(CFURLRef) path;
- (void) audioQueueOutputWithQueue:(AudioQueueRef)audioQueue
                       queueBuffer:(AudioQueueBufferRef)audioQueueBuffer;

static void BufferCallback(void *inUserData, AudioQueueRef inAQ,
                                            AudioQueueBufferRef buffer);
- (UInt32)readPacketsIntoBuffer:(AudioQueueBufferRef)buffer;

@end