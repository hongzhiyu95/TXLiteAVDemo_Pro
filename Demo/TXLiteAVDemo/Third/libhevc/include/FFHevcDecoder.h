//
//  FFHevcDecoder.h
//  hevcdec
//
//  Created by abyyxwang on 2020/12/21.
//  Copyright © 2020 ts. All rights reserved.
//

#ifndef FFHevcDecoder_h
#define FFHevcDecoder_h

#import "TXLiteAVDecoderInterface.h"

namespace liteav {

class FFHevcDecoder : public ITXLiteAVVideoDecoder {
public:
    virtual void SetThreadCount(unsigned threads) = 0;
};

class FFHevcDecoderFactory {
public:
    static FFHevcDecoder* CreateFFHevcDecoder(); //需要自己管理释放
    static void ReleaseFFHevcDecoder(); // 释放指针
protected:
    FFHevcDecoderFactory() = default;
    virtual ~FFHevcDecoderFactory()=default;
    
};

}



#endif /* FFHevcDecoder_h */
