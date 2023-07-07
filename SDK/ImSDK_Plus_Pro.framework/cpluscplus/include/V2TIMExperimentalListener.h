// Copyright (c) 2023 Tencent. All rights reserved.

/////////////////////////////////////////////////////////////////////////////////
//
//                          IMSDK 实验接口监听类
//
/////////////////////////////////////////////////////////////////////////////////

#ifndef __V2TIM_EXPERIMENTAL_LISTENER__
#define __V2TIM_EXPERIMENTAL_LISTENER__

#include "V2TIMCommon.h"

class TIM_API V2TIMExperimentalListener {
public:
    V2TIMExperimentalListener();
    virtual ~V2TIMExperimentalListener();

    /////////////////////////////////////////////////////////////////////////////////
    //
    //                          IMSDK 群属性变更回调
    //
    /////////////////////////////////////////////////////////////////////////////////
    
    /**
     * 群属性 key-value 变更回调
     *
     * @param groupID 群 ID
     * @param key 变更的 key
     * @param newValue 变更后的新值
     */
    virtual void OnGroupAttributeChanged(const V2TIMString &groupID, const V2TIMString &key, const V2TIMString &newValue) {}

    /**
     * 群属性 key 被删除的回调
     *
     * @param groupID 群 ID
     * @param keyList 被删除的 key 列表
     */
    virtual void OnGroupAttributeDeleted(const V2TIMString &groupID, const V2TIMStringVector &keyList) {}
};

#endif /* __V2TIM_EXPERIMENTAL_LISTENER__ */
