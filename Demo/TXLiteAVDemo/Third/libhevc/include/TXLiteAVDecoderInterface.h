#ifndef LITEAV_MODULE_CPP_BASIC_MODULE_LISTENER_TXLITEAVDECODERINTERFACE_H_
#define LITEAV_MODULE_CPP_BASIC_MODULE_LISTENER_TXLITEAVDECODERINTERFACE_H_
#include <memory>

namespace liteav {

enum TXLiteAVVideoFrameType
{
  TXLITEAV_VIDEO_FRAME_TYPE_NONE                       = 0xFFFF,
  TXLITEAV_VIDEO_FRAME_TYPE_IDR                        = 0x0,              //>IDR
  TXLITEAV_VIDEO_FRAME_TYPE_P                          = 0x1,              //>普通P帧
  TXLITEAV_VIDEO_FRAME_TYPE_B                          = 0x2,              //>B帧
  TXLITEAV_VIDEO_FRAME_TYPE_I                          = 0x3,              //>普通I帧，NO-IDR
  TXLITEAV_VIDEO_FRAME_TYPE_P_MULTIREF                 = 0x4,              //>RPS P帧
};

typedef struct DecodedData{
  unsigned char *y_buf;
  unsigned char *u_buf;
  unsigned char *v_buf;
  int y_stride;
  int u_stride;
  int v_stride;
  int width;
  int height;
  uint64_t pts;
};


class ITXLiteAVVideoDecoderCallback {
 public:
  virtual ~ITXLiteAVVideoDecoderCallback() {};
  /**
   *   @param cost_time 解码一帧数据的耗时 单位ms, 用于统计状态
   *   @param decode_data 解码后数据
   */
  virtual void OnDecodeDone(const DecodedData& decoded_data, uint32_t one_frame_cost_time ) = 0;
};

class ITXLiteAVVideoDecoder {
 public:
  virtual ~ITXLiteAVVideoDecoder() {};

  /**
   *  初始化解码器
   *
   */
  virtual bool Initialize() = 0;

  /**
   *  反初始化解码器
   *
   */
  virtual bool UnInitialize() = 0;

  /**
   *  @param 设置解码成功后数据回调接口
   *
   */
  virtual bool SetDecodeCompleteCallBack(ITXLiteAVVideoDecoderCallback* callback) = 0;

  /**
    *  解码数据
    *
    *  @note 返回true 成功，false 表示失败
    *
    */
  virtual bool Decode(uint8_t *in_buf, uint32_t in_buf_len, uint64_t pts, uint64_t dts, TXLiteAVVideoFrameType frame_type) = 0;

  /**
  *   flush解码器,使缓存数据被抛出
  *
  */
  virtual void Flush() = 0;
};

}

#endif //LITEAV_MODULE_CPP_BASIC_MODULE_LISTENER_TXLITEAVDECODERINTERFACE_H_
