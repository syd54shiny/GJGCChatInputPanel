//
//  GJGCCommonInputBar.m
//  GJGroupChat
//
//  Created by ZYVincent on 14-10-28.
//  Copyright (c) 2014年 ZYProSoft. All rights reserved.
//

#import "GJGCChatInputBar.h"

@interface GJGCChatInputBar ()

@property (nonatomic,strong)GJGCChatInputBarItem *recordAudioBarItem;

@property (nonatomic,strong)GJGCChatInputBarItem *emojiBarItem;

@property (nonatomic,strong)GJGCChatInputBarItem *openPanelBarItem;

@property (nonatomic,strong)GJGCChatInputTextView *inputTextView;

@property (nonatomic,copy)GJGCChatInputBarDidChangeActionBlock changeActionBlock;

@property (nonatomic,copy)GJGCChatInputBarDidChangeFrameBlock changeFrameBlock;

@property (nonatomic,copy)GJGCChatInputBarDidTapOnSendTextBlock textSendBlock;

@property (nonatomic,assign)CGFloat itemMargin;

@property (nonatomic,assign)CGFloat itemToBarMargin;

@property (nonatomic,strong)UIView *bottomLine;

@end

@implementation GJGCChatInputBar

#pragma mark - 生命周期

- (instancetype)init
{
    if (self = [super init]) {
        
        [self initSubViews];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        
        [self initSubViews];
    }
    return self;
}

- (void)dealloc
{
    [GJCFNotificationCenter removeObserver:self];
}

#pragma mark - 内部接口

- (void)initSubViews
{
    self.barHeight = 50.f;
    self.inputTextStateBarHeight = self.barHeight;
    
    /* 默认参数 */
    self.itemMargin = 5.f;
    self.itemToBarMargin = 10.f;
    
    /* 首尾分割线  */
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, GJCFSystemScreenWidth, 0.5)];
    [topLine setBackgroundColor:GJCFQuickHexColor(@"d9d9d9")];
    [self addSubview:topLine];
    
    self.bottomLine = [[UIView alloc] initWithFrame:CGRectMake(0, self.barHeight - 0.5, GJCFSystemScreenWidth, 0.5)];
    [self.bottomLine setBackgroundColor:GJCFQuickHexColor(@"d9d9d9")];
    [self addSubview:self.bottomLine];
    
    [self setBackgroundColor:GJCFQuickHexColor(@"f3f3f3")];
    
    /* 录音按钮 */

    UIImage *recordIcon = GJCFQuickImage(@"聊天-icon-语音及切换键盘-灰");
    UIImage *keybordIcon = GJCFQuickImage(@"聊天-icon-文字键盘");
    self.recordAudioBarItem = [[GJGCChatInputBarItem alloc]initWithSelectedIcon:keybordIcon withNormalIcon:recordIcon];
    
    if (GJCFSystemiPhone6Plus) {
        
        self.recordAudioBarItem.frame = CGRectMake(self.itemToBarMargin, 8,35, 35);
        
    }else{
        
        self.recordAudioBarItem.frame = CGRectMake(self.itemToBarMargin, 0,35, 35);
        self.recordAudioBarItem.gjcf_centerY = self.barHeight/2;
    }

    [self addSubview:self.recordAudioBarItem];

    GJCFWeakSelf weakSelf = self;
    [self.recordAudioBarItem configStateChangeEventBlock:^(GJGCChatInputBarItem *item, BOOL changeToState) {
        
        [weakSelf barItem:item changeToState:changeToState];
    }];
    
    [self.recordAudioBarItem configAuthorizeBlock:^BOOL(GJGCChatInputBarItem *item) {
       
        BOOL canUse = weakSelf.disableActionType != GJGCChatInputBarActionTypeRecordAudio;
        
        if ([weakSelf.inputTextView isInputTextFirstResponse]) {
            [weakSelf.inputTextView  resignFirstResponder];
        }
        
        if (!canUse) {
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                NSLog(@"Audio Record Limit!!!!!!");
                
            });
        }
        
        return canUse;
    }];
    
    /* 展开面板按钮 */
    UIImage *extendIcon = GJCFQuickImage(@"聊天-icon-选择照片帖子");
    self.openPanelBarItem = [[GJGCChatInputBarItem alloc]initWithSelectedIcon:keybordIcon withNormalIcon:extendIcon];
    if (GJCFSystemiPhone6Plus) {
        self.openPanelBarItem.frame = CGRectMake(0, 8,35, 35);
    }else{
        self.openPanelBarItem.frame = CGRectMake(0, 0,35, 35);
        self.openPanelBarItem.gjcf_centerY = self.barHeight/2;
    }
    [self addSubview:self.openPanelBarItem];
    self.openPanelBarItem.gjcf_right = GJCFSystemScreenWidth - self.itemToBarMargin;

    [self.openPanelBarItem configStateChangeEventBlock:^(GJGCChatInputBarItem *item, BOOL changeToState) {
        [weakSelf barItem:item changeToState:changeToState];
    }];
    
    /* 输入文本 */
    self.inputTextView = [[GJGCChatInputTextView alloc]initWithFrame:CGRectMake(self.recordAudioBarItem.gjcf_right + self.itemMargin ,0,GJCFSystemScreenWidth - 35 * 3 - 2*self.itemToBarMargin - self.itemMargin * 3 , 32)];
    [self addSubview:self.inputTextView];
    [self.inputTextView setRecordAudioBackgroundImage:GJCFQuickImage(@"输入框-灰色")];
    [self.inputTextView setInputTextBackgroundImage:GJCFQuickImage(@"输入框-白色")];
    [self.inputTextView setPreRecordTitle:@"按住说话"];
    [self.inputTextView setRecordingTitle:@"松开结束"];
    self.inputTextView.gjcf_centerY = self.barHeight/2;
    [self.inputTextView configFinishInputTextBlock:^(GJGCChatInputTextView *textView, NSString *text) {
        if (weakSelf.textSendBlock) {
            weakSelf.textSendBlock(weakSelf,text);
        }
    }];
    [self.inputTextView configTextViewDidBecomeFirstResponse:^(GJGCChatInputTextView *textView) {
        
        weakSelf.inputTextView.recordState = NO;
        weakSelf.recordAudioBarItem.selected = NO;
        
        weakSelf.emojiBarItem.selected = NO;
        weakSelf.openPanelBarItem.selected = NO;
        

    }];
    
    [self.inputTextView configFrameChangeBlock:^(GJGCChatInputTextView *textView, CGFloat changeDetal) {
       
        if (weakSelf.changeFrameBlock) {
            
            weakSelf.gjcf_height +=  changeDetal;
            
            weakSelf.inputTextStateBarHeight = weakSelf.gjcf_height;

            weakSelf.changeFrameBlock(weakSelf,changeDetal);
        
        }
        
    }];
    
    /* 表情按钮 */
    UIImage *emojiIcon = GJCFQuickImage(@"聊天-icon-选择表情");
    self.emojiBarItem = [[GJGCChatInputBarItem alloc]initWithSelectedIcon:keybordIcon withNormalIcon:emojiIcon];
    if (GJCFSystemiPhone6Plus) {
        self.emojiBarItem.frame = CGRectMake(self.inputTextView.gjcf_right+self.itemMargin, 8,35, 35);
    }else{
        self.emojiBarItem.frame = CGRectMake(self.inputTextView.gjcf_right+self.itemMargin, 0,35, 35);
        self.emojiBarItem.gjcf_centerY = self.barHeight/2;
    }
    [self addSubview:self.emojiBarItem];
    [self.emojiBarItem configStateChangeEventBlock:^(GJGCChatInputBarItem *item, BOOL changeToState) {
        [weakSelf barItem:item changeToState:changeToState];
    }];
    
    /* 观察进入前台 */
    [GJCFNotificationCenter addObserver:self selector:@selector(becomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
}

- (void)setupForCommentBarStyle
{
    self.recordAudioBarItem.hidden = YES;
    self.openPanelBarItem.hidden = YES;
    
    self.inputTextView.gjcf_left = self.itemToBarMargin;
    self.inputTextView.gjcf_width = GJCFSystemScreenWidth - 2*self.itemToBarMargin - self.itemMargin - self.emojiBarItem.gjcf_width;
    self.emojiBarItem.gjcf_left = self.inputTextView.gjcf_right + self.itemMargin;
    
}

- (void)setInputTextViewPlaceHolder:(NSString *)inputTextViewPlaceHolder
{
    if ([_inputTextViewPlaceHolder isEqualToString:inputTextViewPlaceHolder]) {
        return;
    }
    
    _inputTextViewPlaceHolder = nil;
    
    _inputTextViewPlaceHolder = [inputTextViewPlaceHolder copy];
    
    self.inputTextView.placeHolder = _inputTextViewPlaceHolder;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.bottomLine.gjcf_bottom = self.gjcf_height;
        
    if (GJCFSystemiPhone6Plus) {
        self.emojiBarItem.gjcf_bottom = self.gjcf_height - 8;
    }else{
        self.emojiBarItem.gjcf_bottom = self.gjcf_height - 7.5;
    }
   
    if (GJCFSystemiPhone6Plus) {
        self.recordAudioBarItem.gjcf_bottom = self.gjcf_height - 8;
    }else{
        self.recordAudioBarItem.gjcf_bottom = self.gjcf_height - 7.5;
    }
    
    if (GJCFSystemiPhone6Plus) {
        self.openPanelBarItem.gjcf_bottom = self.gjcf_height - 8;
    }else{
        self.openPanelBarItem.gjcf_bottom = self.gjcf_height - 7.5;
    }
}

- (void)setPanelIdentifier:(NSString *)panelIdentifier
{
    if ([_panelIdentifier isEqualToString:panelIdentifier]) {
        return;
    }
    _panelIdentifier = nil;
    _panelIdentifier = [panelIdentifier copy];
    [self.inputTextView setPanelIdentifier:panelIdentifier];
}

- (void)barItem:(GJGCChatInputBarItem *)item changeToState:(BOOL)state
{    
    if (item == self.recordAudioBarItem) {
        
        if (state) {
            [self selectActionType:GJGCChatInputBarActionTypeRecordAudio isReserveState:NO];
        }else{
            [self selectActionType:GJGCChatInputBarActionTypeInputText isReserveState:NO];
        }
    }
    
    if (item == self.emojiBarItem) {
        
        if (state) {
            [self selectActionType:GJGCChatInputBarActionTypeChooseEmoji isReserveState:NO];
        }else{
            [self selectActionType:GJGCChatInputBarActionTypeInputText isReserveState:NO];
        }
    }
    
    if (item == self.openPanelBarItem) {
        
        if (state) {
            [self selectActionType:GJGCChatInputBarActionTypeExpandPanel isReserveState:NO];
        }else{
            [self selectActionType:GJGCChatInputBarActionTypeInputText isReserveState:NO];
        }
    }
    
}

#pragma mark - 公开接口

- (void)selectActionType:(GJGCChatInputBarActionType)actionType isReserveState:(BOOL)isReserve
{
    _currentActionType = actionType;

    switch (actionType) {
        case GJGCChatInputBarActionTypeChooseEmoji:
        {
            self.openPanelBarItem.selected = NO;
            self.recordAudioBarItem.selected = NO;
            [self.inputTextView  setRecordState:NO];
            
            if (!isReserve) {
                [self.inputTextView resignFirstResponder];
                [self.inputTextView updateDisplayByInputContentTextChange];
                [self.inputTextView layoutInputTextView];
            }
            
            self.emojiBarItem.selected = YES;

        }
            break;
        case GJGCChatInputBarActionTypeExpandPanel:
        {
            
            self.emojiBarItem.selected = NO;
            self.recordAudioBarItem.selected = NO;
            [self.inputTextView  setRecordState:NO];
            
            if (!isReserve) {
                [self.inputTextView resignFirstResponder];
                [self.inputTextView updateDisplayByInputContentTextChange];
                [self.inputTextView layoutInputTextView];
            }
            
            self.openPanelBarItem.selected = YES;

        }
            break;
        case GJGCChatInputBarActionTypeInputText:
        {
            self.inputTextView.recordState = NO;
            self.recordAudioBarItem.selected = NO;
            
            self.emojiBarItem.selected = NO;
            self.openPanelBarItem.selected = NO;
            
            if (!isReserve) {
                [self.inputTextView becomeFirstResponder];
            }else{
                [self.inputTextView resignFirstResponder];
            }
            
            [self.inputTextView updateDisplayByInputContentTextChange];

        }
            break;
        case GJGCChatInputBarActionTypeRecordAudio:
        {

            self.emojiBarItem.selected = NO;
            self.openPanelBarItem.selected = NO;
            
            if (!isReserve) {
                [self.inputTextView resignFirstResponder];
            }
            
            self.inputTextView.gjcf_height = 32.f;
            
            self.inputTextView.recordState = YES;
            self.recordAudioBarItem.selected = YES;

        }
            break;
        default:
            break;
    }
    
    if (self.changeActionBlock) {
        
        self.changeActionBlock(self,_currentActionType);
    }
}


- (void)configBarDidChangeActionBlock:(GJGCChatInputBarDidChangeActionBlock)actionBlock
{
    if (self.changeActionBlock) {
        self.changeActionBlock = nil;
    }
    self.changeActionBlock = actionBlock;
}

- (void)configBarDidChangeFrameBlock:(GJGCChatInputBarDidChangeFrameBlock)changeBlock
{
    if (self.changeFrameBlock) {
        self.changeFrameBlock = nil;
    }
    self.changeFrameBlock = changeBlock;
}

- (void)configInputBarRecordActionChangeBlock:(GJGCChatInputTextViewRecordActionChangeBlock)actionBlock
{
    if (self.inputTextView) {
        [self.inputTextView configRecordActionChangeBlock:actionBlock];
    }
}

- (void)configBarTapOnSendTextBlock:(GJGCChatInputBarDidTapOnSendTextBlock)sendTextBlock
{
    if (self.textSendBlock) {
        self.textSendBlock = nil;
    }
    self.textSendBlock = sendTextBlock;
}

- (void)reserveState
{
    if (self.currentActionType != GJGCChatInputBarActionTypeRecordAudio) {
        [self selectActionType:GJGCChatInputBarActionTypeInputText isReserveState:YES];
    }
}

- (void)reserveCommentState
{
    if (self.currentActionType == GJGCChatInputBarActionTypeChooseEmoji) {
        
        [self selectActionType:GJGCChatInputBarActionTypeInputText isReserveState:YES];
        
    }else{
        
        [self.inputTextView resignFirstResponder];

    }
}

- (void)inputTextResigionFirstResponse
{
    [self.inputTextView resignFirstResponder];
}

- (BOOL)isInputTextFirstResponse
{
    return [self.inputTextView isInputTextFirstResponse];
}

- (void)inputTextBecomeFirstResponse
{
    [self.inputTextView becomeFirstResponder];
}

- (void)clearInputText
{
    [self.inputTextView clearInputText];
}

- (void)recordRightStartLimit
{
    self.inputTextView.recordState = NO;
    self.recordAudioBarItem.selected = NO;
    
    self.emojiBarItem.selected = NO;
    self.openPanelBarItem.selected = NO;
}

#pragma mark - 进入前台

- (void)becomeActive:(NSNotification *)noti
{
    self.userInteractionEnabled = YES;
}

@end
