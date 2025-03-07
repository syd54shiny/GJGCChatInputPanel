//
//  GJGCChatInputPanel.m
//  GJGroupChat
//
//  Created by ZYVincent on 14-10-28.
//  Copyright (c) 2014年 ZYProSoft. All rights reserved.
//

#import "GJGCChatInputPanel.h"
#import "GJCFAudioRecord.h"
#import "GJCFAudioPlayer.h"
#import "GJGCChatInputRecordAudioTipView.h"
#import "GJCFAssetsPickerViewControllerDelegate.h"

@interface GJGCChatInputPanel ()<
                                GJGCChatInputExpandMenuPanelDelegate,
                                GJCFAssetsPickerViewControllerDelegate,
                                GJCFAudioRecordDelegate
                                >

/* 输入条 */
@property (nonatomic,strong)GJGCChatInputBar *inputBar;

/* 表情面板 */
@property (nonatomic,strong)GJGCChatInputExpandEmojiPanel *emojiPanel;

/* 扩展面板 */
@property (nonatomic,strong)GJGCChatInputExpandMenuPanel  *menuPanel;

/* 录音组件 */
@property (nonatomic,strong)GJCFAudioRecord *audioRecord;

@property (nonatomic,copy)GJGCChatInputPanelKeyboardFrameChangeBlock frameChangeBlock;

@property (nonatomic,copy)GJGCChatInputPanelInputTextViewHeightChangedBlock inputHeightChangeBlock;

@property (nonatomic,strong)GJGCChatInputRecordAudioTipView *recordTipView;

@end

@implementation GJGCChatInputPanel

#pragma mark - 生命周期

- (instancetype)initWithPanelDelegate:(id<GJGCChatInputPanelDelegate>)aDelegate;
{
    if (self = [super init]) {
        
        self.delegate = aDelegate;
        
        _panelIndentifier = [NSString stringWithFormat:@"GJGCChatInputPanel_%@",GJCFStringCurrentTimeStamp];
        
        self.emojiPanel = [[GJGCChatInputExpandEmojiPanel alloc]initWithFrame:CGRectMake(0, self.inputBarHeight, GJCFSystemScreenWidth, 216)];

        [self initSubViews];
        
    }
    return self;
}

- (instancetype)initForCommentBarWithPanelDelegate:(id<GJGCChatInputPanelDelegate>)aDelegate
{
    if (self = [super init]) {
        
        self.delegate = aDelegate;
        
        _panelIndentifier = [NSString stringWithFormat:@"GJGCChatInputPanel_%@",GJCFStringCurrentTimeStamp];
        
        self.emojiPanel = [[GJGCChatInputExpandEmojiPanel alloc]initWithFrameForCommentBarStyle:CGRectMake(0, self.inputBarHeight, GJCFSystemScreenWidth, 216)];

        [self initSubViews];
        
        [self adjustLayoutBarItemForCommentStyle];
    }
    return self;
}

- (void)dealloc
{
    if (self.audioRecord.isRecording) {
        [self.audioRecord cancelRecord];
    }
    [self.inputBar removeObserver:self forKeyPath:@"frame"];
    [GJCFNotificationCenter removeObserver:self];
}

#pragma mark - 内部接口

- (void)initSubViews
{
    self.inputBarHeight = 50;
    self.backgroundColor = GJCFQuickHexColor(@"fafafa");

    /* 输入条 */
    self.inputBar = [[GJGCChatInputBar alloc]initWithFrame:(CGRect){0,0,GJCFSystemScreenWidth,self.inputBarHeight}];
    self.inputBar.barHeight = self.inputBarHeight;
    self.inputBar.panelIdentifier = self.panelIndentifier;
    [self addSubview:self.inputBar];
    
    GJCFWeakSelf weakSelf = self;
    [self.inputBar configBarDidChangeActionBlock:^(GJGCChatInputBar *inputBar, GJGCChatInputBarActionType toActionType) {
        [weakSelf inputBar:inputBar changeToAction:toActionType];
    }];
    
    [self.inputBar configBarDidChangeFrameBlock:^(GJGCChatInputBar *inputBar, CGFloat changeDelta) {
        [weakSelf inputBar:inputBar changeToFrame:changeDelta];
    }];
    
    [self.inputBar configInputBarRecordActionChangeBlock:^(GJGCChatInputTextViewRecordActionType actionType) {
        [weakSelf inputBarRecordActionChange:actionType];
    }];
    
    [self.inputBar configBarTapOnSendTextBlock:^(GJGCChatInputBar *inputBar, NSString *text) {
        [weakSelf inputBar:inputBar sendText:text];
    }];
    
    /* 表情面板 */
    self.emojiPanel.backgroundColor = GJCFQuickHexColor(@"fcfcfc");
    self.emojiPanel.panelIdentifier = self.panelIndentifier;
    [self addSubview:self.emojiPanel];
    
    /* 扩展面板 */
    self.menuPanel = [[GJGCChatInputExpandMenuPanel alloc]initWithFrame:self.emojiPanel.frame withDelegate:self];
    self.menuPanel.backgroundColor = GJCFQuickHexColor(@"fcfcfc");
    [self addSubview:self.menuPanel];
    
    /* 观察通知 */
    [self observePanelInnerEventNoti];
    
    /* 初始化录音组件 */
    [self initAudioRecord];
    
    /* 观察输入内容变化 */
    NSString *formateNoti = [GJGCChatInputConst panelNoti:GJGCChatInputTextViewContentChangeNoti formateWithIdentifier:self.panelIndentifier];
    [GJCFNotificationCenter addObserver:self selector:@selector(updateInputTextContent:) name:formateNoti object:nil];

    [self.inputBar addObserver:self forKeyPath:@"frame" options:NSKeyValueObservingOptionNew context:nil];
    
    [self startKeyboardObserve];
}

- (void)adjustLayoutBarItemForCommentStyle
{
    [self.inputBar setupForCommentBarStyle];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"frame"] && object == self.inputBar) {
        [self.inputBar setNeedsLayout];
    }
}

- (CGFloat)inputBarHeight
{
    if (_currentActionType == GJGCChatInputBarActionTypeRecordAudio) {
        return 50.f;
    }
    return self.inputBar.inputTextStateBarHeight == 0? 50.f:self.inputBar.inputTextStateBarHeight;
}

- (void)setDisableActionType:(GJGCChatInputBarActionType)disableActionType
{
    _disableActionType = disableActionType;
    [self.inputBar setDisableActionType:_disableActionType];
}

- (void)updateInputTextContent:(NSNotification *)noti
{
    _messageDraft = noti.object;
}

- (void)setInputBarTextViewPlaceHolder:(NSString *)inputBarTextViewPlaceHolder
{
    if ([_inputBarTextViewPlaceHolder isEqualToString:inputBarTextViewPlaceHolder]) {
        return;
    }
    
    _inputBarTextViewPlaceHolder = nil;
    _inputBarTextViewPlaceHolder = [inputBarTextViewPlaceHolder copy];
    
    [self.inputBar setInputTextViewPlaceHolder:_inputBarTextViewPlaceHolder];
}

#pragma mark - 输入条 动作响应
- (void)inputBar:(GJGCChatInputBar *)bar changeToAction:(GJGCChatInputBarActionType)actionType
{
    switch (actionType) {
            
        case GJGCChatInputBarActionTypeChooseEmoji:
        {
            self.emojiPanel.hidden = NO;
            [self.emojiPanel reserved];
            self.menuPanel.hidden = YES;
        }
            break;
            
        case GJGCChatInputBarActionTypeExpandPanel:
        {
            self.emojiPanel.hidden = YES;
            self.menuPanel.hidden = NO;
        }
            break;
            
        case GJGCChatInputBarActionTypeInputText:
        {
            
        }
            break;
            
        case GJGCChatInputBarActionTypeRecordAudio:
        {
            self.inputBar.gjcf_height = 50.f;
        }
            break;
            
        default:
            break;
    }
    
    _currentActionType = actionType;
    
    if (self.actionChangeBlock) {
        self.actionChangeBlock(self.inputBar,actionType);
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputPanel:didChangeToInputBarAction:)]) {
        [self.delegate chatInputPanel:self didChangeToInputBarAction:actionType];
    }
}

- (void)inputBarRecordActionChange:(GJGCChatInputTextViewRecordActionType)action
{
    switch (action) {
            
        case GJGCChatInputTextViewRecordActionTypeStart:
        {
            self.inputBar.userInteractionEnabled = NO;
            if (self.recordStateChangeBlock) {
                self.recordStateChangeBlock(self,YES);
            }
            
            [self.audioRecord startRecord];
            
            /* 通知聊天详情页面停止播放语音 */
            NSString *formateNoti = [GJGCChatInputConst panelNoti:GJGCChatInputPanelBeginRecordNoti formateWithIdentifier:self.panelIndentifier];
            GJCFNotificationPost(formateNoti);
        }
            break;
            
        case GJGCChatInputTextViewRecordActionTypeFinish:
        {
            self.inputBar.userInteractionEnabled = YES;
            if (self.recordStateChangeBlock) {
                self.recordStateChangeBlock(self,NO);
            }
            
            [self.audioRecord finishRecord];
        }
            break;
            
        case GJGCChatInputTextViewRecordActionTypeCancel:
        {
            self.inputBar.userInteractionEnabled = YES;
            if (self.recordStateChangeBlock) {
                self.recordStateChangeBlock(self,NO);
            }
            
            [self.audioRecord cancelRecord];
        }
            break;
        case GJGCChatInputTextViewRecordActionTypeTooShort:
        {
            self.inputBar.userInteractionEnabled = YES;
            if (self.recordStateChangeBlock) {
                self.recordStateChangeBlock(self,NO);
            }
            
            [self showRecordTipView];
        }
            break;
        default:
            break;
    }
}

- (void)inputBar:(GJGCChatInputBar *)bar changeToFrame:(CGFloat)changeDelta
{
    if (self.inputHeightChangeBlock) {
        
        self.emojiPanel.gjcf_top = bar.gjcf_bottom;
        self.menuPanel.gjcf_top = bar.gjcf_bottom;
        
        self.inputHeightChangeBlock(self,changeDelta);
        
    }
}


- (void)inputBar:(GJGCChatInputBar *)bar sendText:(NSString *)text
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputPanel:sendTextMessage:)]) {
        [self.delegate chatInputPanel:self sendTextMessage:text];
    }
}

#pragma mark - 录音按钮触摸检测
- (void)showRecordTipView
{
    if (self.recordTipView) {
        [self.recordTipView removeFromSuperview];
        self.recordTipView = nil;
    }
    self.recordTipView = [[GJGCChatInputRecordAudioTipView alloc]init];
    self.recordTipView.isTooShortRecordDuration = YES;
    [[ [UIApplication sharedApplication] keyWindow] addSubview:self.recordTipView];
    [self removeRecordTipView];
}

- (void)removeRecordTipView
{
    GJCFAsyncMainQueueDelay(0.5, ^{
        
        if (self.recordTipView) {
            [self.recordTipView removeFromSuperview];
            self.recordTipView = nil;
        }
        
    });
}

#pragma mark - 录音管理
- (void)initAudioRecord
{
    self.audioRecord = [[GJCFAudioRecord alloc]init];
    self.audioRecord.delegate = self;
    self.audioRecord.limitRecordDuration = 60.0f;
    self.audioRecord.minEffectDuration = 1.f;
}

- (void)audioRecord:(GJCFAudioRecord *)audioRecord didFaildByMinRecordDuration:(NSTimeInterval)minDuration
{
    NSLog(@"最小录音时间失败:%f",minDuration);
    [self showRecordTipView];
}

- (void)audioRecord:(GJCFAudioRecord *)audioRecord didOccusError:(NSError *)error
{
    NSLog(@"录音失败:%@",error);
}
- (void)audioRecord:(GJCFAudioRecord *)audioRecord finishRecord:(GJCFAudioModel *)resultAudio
{
    NSLog(@"录音成功:%@",resultAudio.description);
    
    NSString *formateNoti = [GJGCChatInputConst panelNoti:GJGCChatInputTextViewRecordTooLongNoti formateWithIdentifier:self.panelIndentifier];

    GJCFNotificationPost(formateNoti);
    
    /**
     *  录音文件转码
     */
    [GJCFAudioFileUitil setupAudioFileTempEncodeFilePath:resultAudio];
    
    if ([GJCFEncodeAndDecode convertAudioFileToAMR:resultAudio]) {
        
        NSLog(@"ChatInputPanel 录音文件转码成功");
        NSLog(@"%@",resultAudio);
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputPanel:didFinishRecord:)]) {
            [self.delegate chatInputPanel:self didFinishRecord:resultAudio];
        }
    }    
}
- (void)audioRecord:(GJCFAudioRecord *)audioRecord limitDurationProgress:(CGFloat)progress
{
//    NSLog(@"最大录音限制进度:%f",progress);
}
- (void)audioRecord:(GJCFAudioRecord *)audioRecord soundMeter:(CGFloat)soundMeter
{
//    NSLog(@"录音音量:%f",soundMeter);
    
    NSString *formateNoti = [GJGCChatInputConst panelNoti:GJGCChatInputTextViewRecordSoundMeterNoti formateWithIdentifier:self.panelIndentifier];

    GJCFNotificationPostObj(formateNoti,@(soundMeter));
    
}
- (void)audioRecordDidCancel:(GJCFAudioRecord *)audioRecord
{
    NSLog(@"录音取消");
}


#pragma mark - 扩展面板 Delegate
- (void)menuPanel:(GJGCChatInputExpandMenuPanel *)panel didChooseAction:(GJGCChatInputMenuPanelActionType)action
{    
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputPanel:didChooseMenuAction:)]) {
        
        [self.delegate chatInputPanel:self didChooseMenuAction:action];
    }
    
}

- (GJGCChatInputExpandMenuPanelConfigModel *)menuPanelRequireCurrentConfigData:(GJGCChatInputExpandMenuPanel *)panel;
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputPanelRequiredCurrentConfigData:)]) {
        
        return [self.delegate chatInputPanelRequiredCurrentConfigData:self];

    }else{
        
        return nil;
    }
}

#pragma mark - 键盘事件

- (void)configInputPanelKeyboardFrameChange:(GJGCChatInputPanelKeyboardFrameChangeBlock)changeBlock
{
    if (self.frameChangeBlock) {
        self.frameChangeBlock = nil;
    }
    self.frameChangeBlock = changeBlock;
}

- (void)configInputPanelRecordStateChange:(GJGCChatInputPanelRecordStateChangeBlock)recordChangeBlock
{
    if (self.recordStateChangeBlock) {
        self.recordStateChangeBlock = nil;
    }
    self.recordStateChangeBlock = recordChangeBlock;
}

- (void)configInputPanelInputTextViewHeightChangedBlock:(GJGCChatInputPanelInputTextViewHeightChangedBlock)heightChangeBlock
{
    if (self.inputHeightChangeBlock) {
        self.inputHeightChangeBlock = nil;
    }
    self.inputHeightChangeBlock = heightChangeBlock;
}

#pragma mark - 观察键盘事件
- (void)keyboardWillChangeFrame:(NSNotification *)noti
{
    CGRect keyboardBeginFrame = [noti.userInfo[@"UIKeyboardFrameBeginUserInfoKey"] CGRectValue];
    CGRect keyboardEndFrame = [noti.userInfo[@"UIKeyboardFrameEndUserInfoKey"] CGRectValue];
    CGFloat duration = [noti.userInfo[@"UIKeyboardAnimationDurationUserInfoKey"] doubleValue];
    
    if (self.frameChangeBlock) {
        if (self.inputBar.currentActionType == GJGCChatInputBarActionTypeChooseEmoji || self.inputBar.currentActionType == GJGCChatInputBarActionTypeExpandPanel) {
            self.frameChangeBlock(self,keyboardBeginFrame,keyboardEndFrame,duration,NO);
        }else{
            self.frameChangeBlock(self,keyboardBeginFrame,keyboardEndFrame,duration,YES);
        }
    }
    
}

- (void)startKeyboardObserve
{
    /* 观察键盘事件 */
    [GJCFNotificationCenter addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)removeKeyboardObserve
{
    [GJCFNotificationCenter removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

#pragma mark - 观察内部事件通知

- (void)observePanelInnerEventNoti
{
    /* 观察表情键盘发送事件 */
    NSString *formateNoti = [GJGCChatInputConst panelNoti:GJGCChatInputExpandEmojiPanelChooseSendNoti formateWithIdentifier:self.panelIndentifier];
    [GJCFNotificationCenter addObserver:self selector:@selector(observeEmojiPanelSend:) name:formateNoti object:nil];
    
    /* 观察gif表情键盘发送事件 */
    NSString *formateGifSendNoti = [GJGCChatInputConst panelNoti:GJGCChatInputExpandEmojiPanelChooseGIFEmojiNoti formateWithIdentifier:self.panelIndentifier];
    [GJCFNotificationCenter addObserver:self selector:@selector(observeGifEmojiPanelSend:) name:formateGifSendNoti object:nil];

}

#pragma mark - 表情键盘事件

- (void)observeEmojiPanelSend:(NSNotification *)noti
{
    /* 是否纯空格 */
    BOOL isAllWhiteSpace = GJCFStringIsAllWhiteSpace(self.messageDraft);
    if (isAllWhiteSpace) {
//        [[NSNotificationCenter defaultCenter] postNotificationName:GJGC_NOTIFICATION_TOAST_NAME object:nil userInfo:@{@"message":@"不允许发送空信息"}];
        return;
    }
    if (self.messageDraft.length == 0) {
        return;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputPanel:sendTextMessage:)]) {
        
        [self.inputBar clearInputText];
        
        [self.delegate chatInputPanel:self sendTextMessage:self.messageDraft];
        
        _messageDraft = @"";

    }
}

- (void)observeGifEmojiPanelSend:(NSNotification *)noti
{
    NSString *gifLocalId = noti.object;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(chatInputPanel:sendGIFMessage:)]) {
        
        [self.delegate chatInputPanel:self sendGIFMessage:gifLocalId];
    }
}

- (void)reserveState
{
    [self.inputBar reserveState];
}

- (void)reserveCommentState
{
    [self.inputBar reserveCommentState];
}

- (void)recordRightStartLimit
{
    [self.inputBar recordRightStartLimit];
}

- (void)inputBarRegsionFirstResponse
{
    [self.inputBar inputTextResigionFirstResponse];
}

- (BOOL)isInputTextFirstResponse
{
    return [self.inputBar isInputTextFirstResponse];
}

- (void)becomeFirstResponse
{
    [self.inputBar inputTextBecomeFirstResponse];
}

- (void)setLastMessageDraft:(NSString *)msgDraft
{
    _messageDraft = [msgDraft copy];
    NSString *formateNoti = [GJGCChatInputConst panelNoti:GJGCChatInputSetLastMessageDraftNoti formateWithIdentifier:self.panelIndentifier];
    GJCFNotificationPostObj(formateNoti, msgDraft);
}

- (void)appendFocusOnOther:(NSString *)otherName
{
    if (GJCFStringIsNull(otherName)) {
        return;
    }
    
    NSString *formateNoti = [GJGCChatInputConst panelNoti:GJGCChatInputPanelNeedAppendTextNoti formateWithIdentifier:self.panelIndentifier];
    GJCFNotificationPostObj(formateNoti, otherName);
    
}

@end
