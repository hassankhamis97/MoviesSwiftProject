/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "UIView+WebCache.h"
#import "objc/runtime.h"
#import "UIView+WebCacheOperation.h"

NSString * const SDWebImageInternalSetImageGroupKey = @"internalSetImageGroup";
NSString * const SDWebImageExternalCustomManagerKey = @"externalCustomManager";

const int64_t SDWebImageProgressUnitCountUnknown = 1LL;

static char imageURLKey;

#if SD_UIKIT
static char TAG_ACTIVITY_INDICATOR;
static char TAG_ACTIVITY_STYLE;
static char TAG_ACTIVITY_SHOW;
#endif

@implementation UIView (WebCache)

- (nullable NSURL *)sd_imageURL {
    return objc_getAssociatedObject(self, &imageURLKey);
}

- (NSProgress *)sd_imageProgress {
    NSProgress *progress = objc_getAssociatedObject(self, @selector(sd_imageProgress));
    if (!progress) {
        progress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
        self.sd_imageProgress = progress;
    }
    return progress;
}

- (void)setSd_imageProgress:(NSProgress *)sd_imageProgress {
    objc_setAssociatedObject(self, @selector(sd_imageProgress), sd_imageProgress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                      operationKey:(nullable NSString *)operationKey
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                         completed:(nullable SDExternalCompletionBlock)completedBlock {
    return [self sd_internalSetImageWithURL:url placeholderImage:placeholder options:options operationKey:operationKey setImageBlock:setImageBlock progress:progressBlock completed:completedBlock context:nil];
}

- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                      operationKey:(nullable NSString *)operationKey
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                         completed:(nullable SDExternalCompletionBlock)completedBlock
                           context:(nullable NSDictionary<NSString *, id> *)context {
    SDInternalSetImageBlock internalSetImageBlock;
    if (setImageBlock) {
        internalSetImageBlock = ^(UIImage * _Nullable image, NSData * _Nullable imageData, SDImageCacheType cacheType, NSURL * _Nullable imageURL) {
            if (setImageBlock) {
                setImageBlock(image, imageData);
            }
        };
    }
    [self sd_internalSetImageWithURL:url placeholderImage:placeholder options:options operationKey:operationKey internalSetImageBlock:internalSetImageBlock progress:progressBlock completed:completedBlock context:context];
}

- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                      operationKey:(nullable NSString *)operationKey
             internalSetImageBlock:(nullable SDInternalSetImageBlock)setImageBlock
                          progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                         completed:(nullable SDExternalCompletionBlock)completedBlock
                           context:(nullable NSDictionary<NSString *, id> *)context {
    NSString *validOperationKey = operationKey ?: NSStringFromClass([self class]);
    [self sd_cancelImageLoadOperationWithKey:validOperationKey];
    objc_setAssociatedObject(self, &imageURLKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    dispatch_group_t group = context[SDWebImageInternalSetImageGroupKey];
    if (!(options & SDWebImageDelayPlaceholder)) {
        if (group) {
            dispatch_group_enter(group);
        }
        dispatch_main_async_safe(^{
            [self sd_setImage:placeholder imageData:nil basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:SDImageCacheTypeNone imageURL:url];
        });
    }
    
    if (url) {
#if SD_UIKIT
        // check if activityView is enabled or not
        if ([self sd_showActivityIndicatorView]) {
            [self sd_addActivityIndicator];
        }
#endif
        
        // reset the progress
        self.sd_imageProgress.totalUnitCount = 0;
        self.sd_imageProgress.completedUnitCount = 0;
        
        SDWebImageManager *manager = [context objectForKey:SDWebImageExternalCustomManagerKey];
        if (!manager) {
            manager = [SDWebImageManager sharedManager];
        }
        
        __weak __typeof(self)wself = self;
        SDWebImageDownloaderProgressBlock combinedProgressBlock = ^(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL) {
            wself.sd_imageProgress.totalUnitCount = expectedSize;
            wself.sd_imageProgress.completedUnitCount = receivedSize;
            if (progressBlock) {
                progressBlock(receivedSize, expectedSize, targetURL);
            }
        };
        id <SDWebImageOperation> operation = [manager loadImageWithURL:url options:options progress:combinedProgressBlock completed:^(UIImage *image, NSData *data, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
            __strong __typeof (wself) sself = wself;
            if (!sself) { return; }
#if SD_UIKIT
            [sself sd_removeActivityIndicator];
#endif
            // if the progress not been updated, mark it to complete state
            if (finished && !error && sself.sd_imageProgress.totalUnitCount == 0 && sself.sd_imageProgress.completedUnitCount == 0) {
                sself.sd_imageProgress.totalUnitCount = SDWebImageProgressUnitCountUnknown;
                sself.sd_imageProgress.completedUnitCount = SDWebImageProgressUnitCountUnknown;
            }
            BOOL shouldCallCompletedBlock = finished || (options & SDWebImageAvoidAutoSetImage);
            BOOL shouldNotSetImage = ((image && (options & SDWebImageAvoidAutoSetImage)) ||
                                      (!image && !(options & SDWebImageDelayPlaceholder)));
            SDWebImageNoParamsBlock callCompletedBlockClojure = ^{
                if (!sself) { return; }
                if (!shouldNotSetImage) {
                    [sself sd_setNeedsLayout];
                }
                if (completedBlock && shouldCallCompletedBlock) {
                    completedBlock(image, error, cacheType, url);
                }
            };
            
            // case 1a: we got an image, but the SDWebImageAvoidAutoSetImage flag is set
            // OR
            // case 1b: we got no image and the SDWebImageDelayPlaceholder is not set
            if (shouldNotSetImage) {
                dispatch_main_async_safe(callCompletedBlockClojure);
                return;
            }
            
            UIImage *targetImage = nil;
            NSData *targetData = nil;
            if (image) {
                // case 2a: we got an image and the SDWebImageAvoidAutoSetImage is not set
                targetImage = image;
                targetData = data;
            } else if (options & SDWebImageDelayPlaceholder) {
                // case 2b: we got no image and the SDWebImageDelayPlaceholder flag is set
                targetImage = placeholder;
                targetData = nil;
            }
            
#if SD_UIKIT || SD_MAC
            // check whether we should use the image transition
            SDWebImageTransition *transition = nil;
            if (finished && (options & SDWebImageForceTransition || cacheType == SDImageCacheTypeNone)) {
                transition = sself.sd_imageTransition;
            }
#endif
            dispatch_main_async_safe(^{
                if (group) {
                    dispatch_group_enter(group);
                }
#if SD_UIKIT || SD_MAC
                [sself sd_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:transition cacheType:cacheType imageURL:imageURL];
#else
                [sself sd_setImage:targetImage imageData:targetData basedOnClassOrViaCustomSetImageBlock:setImageBlock cacheType:cacheType imageURL:imageURL];
#endif
                if (group) {
                    // compatible code for FLAnimatedImage, because we assume completedBlock called after image was set. This will be removed in 5.x
                    BOOL shouldUseGroup = [objc_getAssociatedObject(group, &SDWebImageInternalSetImageGroupKey) boolValue];
                    if (shouldUseGroup) {
                        dispatch_group_notify(group, dispatch_get_main_queue(), callCompletedBlockClojure);
                    } else {
                        callCompletedBlockClojure();
                    }
                } else {
                    callCompletedBlockClojure();
                }
            });
        }];
        [self sd_setImageLoadOperation:operation forKey:validOperationKey];
    } else {
        dispatch_main_async_safe(^{
#if SD_UIKIT
            [self sd_removeActivityIndicator];
#endif
            if (completedBlock) {
                NSError *error = [NSError errorWithDomain:SDWebImageErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey : @"Trying to load a nil url"}];
                completedBlock(nil, error, SDImageCacheTypeNone, url);
            }
        });
    }
}

- (void)sd_cancelCurrentImageLoad {
    [self sd_cancelImageLoadOperationWithKey:NSStringFromClass([self class])];
}

- (void)sd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(SDInternalSetImageBlock)setImageBlock cacheType:(SDImageCacheType)cacheType imageURL:(NSURL *)imageURL {
#if SD_UIKIT || SD_MAC
    [self sd_setImage:image imageData:imageData basedOnClassOrViaCustomSetImageBlock:setImageBlock transition:nil cacheType:cacheType imageURL:imageURL];
#else
    // watchOS does not support view transition. Simplify the logic
    if (setImageBlock) {
        setImageBlock(image, imageData, cacheType, imageURL);
    } else if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)self;
        [imageView setImage:image];
    }
#endif
}

#if SD_UIKIT || SD_MAC
- (void)sd_setImage:(UIImage *)image imageData:(NSData *)imageData basedOnClassOrViaCustomSetImageBlock:(SDInternalSetImageBlock)setImageBlock transition:(SDWebImageTransition *)transition cacheType:(SDImageCacheType)cacheType imageURL:(NSURL *)imageURL {
    UIView *view = self;
    SDInternalSetImageBlock finalSetImageBlock;
    if (setImageBlock) {
        finalSetImageBlock = setImageBlock;
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, SDImageCacheType setCacheType, NSURL *setImageURL) {
            imageView.image = setImage;
        };
    }
#if SD_UIKIT
    else if ([view isKindOfClass:[UIButton class]]) {
        UIButton *button = (UIButton *)view;
        finalSetImageBlock = ^(UIImage *setImage, NSData *setImageData, SDImageCacheType setCacheType, NSURL *setImageURL) {
            [button setImage:setImage forState:UIControlStateNormal];
        };
    }
#endif
    
    if (transition) {
#if SD_UIKIT
        [UIView transitionWithView:view duration:0 options:0 animations:^{
            // 0 duration to let UIKit render placeholder and prepares block
            if (transition.prepares) {
                transition.prepares(view, image, imageData, cacheType, imageURL);
            }
        } completion:^(BOOL finished) {
            [UIView transitionWithView:view duration:transition.duration options:transition.animationOptions animations:^{
                if (finalSetImageBlock && !transition.avoidAutoSetImage) {
                    finalSetImageBlock(image, imageData, cacheType, imageURL);
                }
                if (transition.animations) {
                    transition.animations(view, image);
                }
            } completion:transition.completion];
        }];
#elif SD_MAC
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext * _Nonnull prepareContext) {
            // 0 duration to let AppKit render placeholder and prepares block
            prepareContext.duration (NSInteger redprepares block
              }];
#elif SD_MACation (NSauheder redpre_group_entk
       tk
ted }];
#];
Data *)iation (NS asedOnCredpre_graustomSe
       tadprepares block
         n (NS aseeCo    pre_grionion.C
       tivityIndicator];
#end     n (Nes)onion.C
 pre_grion:^{
          ivityIndiw, ar];
#end     n (NesdurNon.C
 pre_grion:^{
          ck
ayIndiw, ar];
#end   arransition.animations) {
 :^{
     
N   ck
ayIndiw, ar];
#end   arayI       } elseions) iti   
     
N = [SDWebImageManager sh   arayI ltmple} else  }         
     stD_MASDWebIititk
tager sh   arayI ltmManl 
     st        
} elseions) CWebIititkons)ar sh   arayI ltmMananlsition.a       
}bIireions) CWebIititkontkodiw, ar]rayI ltmM   nlsition.a       
}   ti   
  CWebIititt otkodiw, ar]rayI ltmM   , aorion.a       
}   ti  
   CWebIititt otkodiw, ai  orI ltmM   , aorion.a.an    
}   ti  
   CWebIitti sdurNon.C ai  orI sOrV   , aorion.a.an I liw, ar];

   CWebI.a.      n n.C aiNonso sOrV   , aorion.a.an I  ,ga ar];

   CWebI.a.      n n.C aiNonso sOrV   ,.a.gaon.a.an I  ,ga ar]; arS CWebI.a.      n n.C air];e.C
 pre_ ,.a.gnsoion]d I  ,ga a}];
#elif SD_Md.      n OrV   ,.a.gaon.a.an .a.gnsoion]d I  ,gaodi ;
#elif SD_Md.      n On O    n n.C aiNonso sOrsoion]d Iau gaodi ;
#elif SD_Md.    ;
I.a.      n n.C aiNonso sOrsoi y  stD_MAaodi ;on]}k
tager .    ;Md.uo      n n.C aiNonso sOr ai/y  stD_MAaodi ;on]}k
tastD/.    ;Md.uo      n n.C  . /nso sOr ai/y  stD_MAaod ai/n]}k
tastD/.    ;Md.uo    alS n.C  . /d.uoaOr ai/y  stD_MAaod }];titt otstD/. D_Mon]}uo    alS n.C  . /d.uoaOr ai/ I rtD_MAaod }];titt oton]iw, ai n]}uo ;ti"rS n.C  . /d.uoaOr a ai ti  
 Aaod }i/ Si sdurN]iw, a;titkontkodiwS n.C  . n.Can I liwai ti a ae;

   CWeb sdurN]iwSi sC  . n.CadiwS n.C od }];dn I liwai)er a ae;

   CWeb sdu SigwSi sC  . n.Cadiw. nsr od }];dn I liwai)edn ar]; arS CWebI.du SigwSi   
N   ck
ayIndiw, ar }];dn I Manai)edn ar]; arS CWeb  .  n OrVi   
NwSieL
ayIndiw, ar }];d  c.aanai)edn ar]; arS C  a     n OrVi  WebngieL
ayIndiw, ar }ayI)rc.aanai)edn ar]; arMond.    ; n OrV   dn agieL
ayIndiw, ar Ind#)rc.aanai)edn ar].aa#Mond.    ; n OrV ; a# agieL
ayIndiw, a  ;#d#)rc.aanai)edn anaiOrVMond.      , OrV ; a# agieL
ayIndiwa# ir;#d#)rc.aanai)edn a;d 
tastD/.    ;M, OrV anaion.ieL
ayInde_ga ir;#d#)rc.aanai)edyInitt otstD/. D_ ;M, Otas^raion.ieL
ayInde_ga a isnitt otstai)edy#d# sOtas^raioD_ ;M,t o*T^raion.ieL
ayInde_g
taey#d# sOtastai)edy#hSi sdurN]iw, a ;M,t tas
diwS n.C  . n.de_g
taeys^r sOtastai)edy#hSi sdurN]iw, atitat tas
diwS n.C  . n oteai)edy#hS sOtas_g
 Ind#)rc.aanai)ed, atitat  =oteai)edyC  . n ot# agieL
ayIndtas_g
 IncatoC.aanai)edtimage, imageDataedyC  . na}s_g
 IncaayIndtL
a IncaaatoC.aanai)edtimage, imageDat; arC  . na}s_g
 Incaay#d#;L
a IncaaatoC.aanaidur;image, imageDat; arwS ; na}s_g
 Incaay#d#;^r ;IncaaatoC.aanaidur;urN;e, imageDat; arwS ;geD)r ;Incaaaay#d#;rwSe) {
                rN;e, aan   CWebarwS ;geDtD/aIncaaaay#d#;rwSe) {t# ;             rN;e, dy#;  CWebarwS ;geDtD/aat ;aaay#d#;rwSe) {t# ;ote;         rN;e, dy#;rwS0ebarwS ;geDtD/aat ;mag;#d#;rwSe) {t# ;ote; na;     rN;e, dy#;rwS0 In;wS ;geDtD/aat ;mag;   0rwSe) {t# ;ote; na; {tk rN;e, dy#;rwS0 In;wS ;geDtD/nair;mag;   0rwSe) {t# , d0; na; {tk rN;e, dy#Inc;0 In;wS ;geDtD/nair{t#0;   0rwSe) {t# , d0aan;; {tk rN;e, dy#Inc;aIn;;wS ;geDtD/nair{t#0 ; ;0rwSe) {t# , d0aan;t#0kk rN;e, dy#Inc;aIn;;wS ;geDtDn]}ar{t#0 ; ;0rwSe) {t#   ;0aan;t#0kk rN;e, dywS ;;aIn;;wS ;geDtDn]}a;rw;0 ; ;0rwSe) {t#   ;n;;0;t#0kk rN;e, dywS ; In . nS ;geDtDnoe) rw;0 ; ;0DtDons{t#   ; ; 
a #0kk rN;eDImawS ; In . nS ;geDtDD/nay#d;0 ; ;0Dtay#s{t#   ; ; 
a #0kk rN;eDImawSywSwS ; nS ;geDtmawS ; In . nS ;tay#s{t#   ; ; 
a  ;;aIn;;eDImawSyrwS ; In . nSDtmawS ; p#;rwnS ;tay#s nS ;tay#s{t#   ; n;;eDImawSyrwS ; In . nSDtmaw;ge; In . nS;tay#s nSt         rN;e, dy#;rwS0ebarwS ;ge . nSDtma 
a # In . nS;tay#s nSt         rNInc;ge . nSDtbarwS 0eb /d.uotma 
a # e, dd.uotma 
 nSt     ;ge . nSc;ge . nSDtbarwS 0eb /darw ;tay#s{te, dd.uot;ge, d0t     ;geRrN;ec;ge . nSdduration to larw ;t. n Nte, dd.uot;ge, d0t     {teeaN;ec;ge . nSddura;ge;geDtD/nair{t#0 ; ;0rwSe)ot;ge, d0d# sOC{teeaN;ec[le . nSddura;ge;geDtD/nadur"#0 ; ;0rwSe)ot;ge, d0d#, d
  eeaN;ec[l; a nSddura;ge;geDtD;geldura;ge;g0rwSe)ot; Na;ge;g0rw
  eeaN;e#0 eDtD;geldra;ge;geDSr;geldura;ge;g0rwSg0rSeaN;e#0 eDrw
  eg0rt e;geDSr;geldra;ge;g ; C;geldura;eaag0rwSg0rSeaN;e#0 uraaa  eg0rt e;geDSr;gN;eaa;ge;g ; C;geldura;eanS ;geDtmaeaN;e#0 ugeD;gN;eaa;ge;geDSr;gI.a.      n n.C aiNora;eanS ;.  tmaeaN;e#0 ugeD;gN;eaa;ge;geDeaNwS ; In    n n.C aayIra;eanS ;.  tmaeaN;;e#     rN;e, dy#e;geDeaNwt.uo n    n n.nSDayIra;eanS ;.  tmaeaN;;;;e . nS;tay#sy#e;geDeanS ;yIra;eanS n.nSDauo [aeanS ;.  tmaeaN;;  tpDeanS ;yIry#e;ge. n.r ;yIra;eanS n.nSD n.taaeanS ;.  tmaeaN;anS,e. n.r ;yIry#e;geaN        a;eanS n.aaa n.taaeanS ;.  tmaeaN;anaeaarw.r ;yIry#anSeaarw.r ;y a;eanS ncgeR n.taaeanDeancgeR n.t;anaeaarwS ;.  tmaeaN;anaeaarw. a;eanS ncgeR n.tanSn.a  ncgeR n.tsleaN;anaeaa.  tma ;.sancgeR n.ta;eanS. atddur.tanSn.a a"aeaa.  tmaeaN;anslestD/.ma ;.sanc    n.ta;eanS. atddu. age;geDSr;geldu  tmaeaN;egeldura;ge; ;.sanc   ti.ta;eanS. atddu. age;geanc;eldura;geaeaN;ege;ura;gde; ;.sancEebI.a.    nS. atnS.rt e;geDanc;eldur   soion]d I;ura;g;geTion]d I;uI.a.    nw
  tnS.rt e;geDanc;eanch;g;geTion] I;ura]d t I  ,gaod;uI.a. I;-Danc;eancht e;ge.rtnS. aCh;g;geTiot     ;geRdt I  ,gaoii ;
#elif SD_Mdeanchtc;er.C aiNonsoh;g;ge;ge#elif SD_Mdt I  ,gaoui ;on]}k
tager eanchtMden.C aiNonsoh;g;geD_Mt stD_MAaodt I  ge#.tD_MAaodt
tager eat I  ge#.tD_MNonsoh;g;geD_Mt stD_MAastD. I ge#.tD_MIn ge#.tD_MNoat I  ge#nS n.aaa n.taaeanS ;.  tmaeaN;anae ge#.tD_M  . D_Mon]}uo      ge#n#.te#elin.taaeanS;yIe#elin.taanae ge#.    ; . D_Mon]}uo     M   ai/ I rlin.taaeaiw. nsrelin.taanatin]}uo     . D_Mon]},h     M   ai/ I rlin.taaeaiw. aiw liw.taanan.ttD/o     . De, / I rlin.tM   ai/ ISelin.taaeaiw. aiw liw.taiw.i.ta;eanS. atddu. age;geanc;eldura;geaeain.taa  atnta;eanS. taiw.i. ax;geanc;eldu. age;ge;ura]d t d;geaeain.eohC atnta;eatdd taiw.i. ax;geanc;eldu. taohCe;ura]d tbeL
ayIndn.eohCe;u.ea;eatdd taiw.i. ax;geaneaneiw.i. ax;geanead tbeL
ay)egeanead tbeL
ayatdd taiw   M   ai/ I reiw.i. ax;geanead tbeL
ay)egegeasd tbeL
ayatdd taiw   M eL
]}k
tager eanchtMden.C aiNeL
ay)egey_asd tbeL
ayatdd taiw   beL taiw.i. ax eanchtMd0DtC aiNeL
ay)egey_a)egw  beL taiw taiw   bw
 taiw.i. ax eanchtMd0DtC aiNelinhCegey_a)eg,v beL taiw taiw   iw .tMd0DtC ai eanchax m
tC aiNelinhCegey_a)eg,v beL te#.hCaiw   iw dRMd0DtC ai eanchaxtC )hCaiNelinhClRey_a)eg,v beL te#hCe)hC   iw dRMrRDtC ai eanchaxtC ai GiNelinhClRey_a)egaiNGeL te#hCe)hC   iwClRaeaDtC ai ea  CWxtC ai GiNelinhClRey_a)egaiNG. nhC#hCe)hC  hu  CWxtC aC ai ea  
]}k
tager eanchdClRey_a)eC aiNe nhC#hCe)hC  hu  CW)hC.aC ai ea  
]}k
tahC          Rey_a)eC aiNe nhC#hCe)hC  hu geT}k
tahC   ea  
]  hs.hC          Rey_aea m hu geT}k
Ce)hC  hui.eT}k
tahC   ea  
T}keUChC       D_MNonsoh;gd hu geT}knch;g;geTion] I;ura]d t I  ,gaod;uI.a. I;-Danc;eancht e;ge.rtnS. aCh;g;geTiot     ;geRdt I  ,gaoii ;
#elif SD_Mdeanchtc;er.C aiNonsoh;g;ge;ge#elif SD_Mdt I  ,gaoui ;on]}k
tager eanchtMden.C aiNonsoh;g;geD_Mt stD_MAaodt I  ge#.tD_MAaodt
tager eat I  ge#.tD_MNonsoh;g;ggaoihCstD_MAaodd}I  ge#.tD_MAaodt
tager .tDaat ;mag;   0rwSe) {t#gaoihC;gg#gaoodd}I  ge#.tD_MAaodt
ta_MAV.tDaat ;mag;   0rwSe) { ;mVoihC;gg#gaoodd}I  ge#.thC;Vaodt
ta_MAV.tDaat ;mag;#.tVrwSe) { ;mVoihC;gg#gaoooodVrwCe#.thC;Vag#gaoodd}I  gaat ;mag;#.tVrwSe) { ;mVoihC;MAaUCoooodVrwClllllC;Vag#gaoodd}I  gaat ;mag;#.t#.t)e) { ;mVoihC;MAaUCooood.tV)e)CllC;Vag#g nhCd}I  gaatD_MAaodt I  ge#.tD_MCoihC;MAaUoooo#g nhCd}IllC;Va)Cla:hCd}I  gaatD_MAaodt I  d}Ig;#.tVrwSe) { ;mooo#g nhCr ea gaatD_MAahCd}I a:hvUC_MAaodt ItD_MAahCd}I a:hvUC_MAaodt ItD_MAaC gaatD_MAfcdt ItD_MAUC_MAaaatIKCD_MAahCd}AaC gaatD_MAfcdtItD_MAaC gaatD_MAD_MtUCtD_MAUC_MSaaatIKCD_MAahCd}AaC gaatD_MAfcdtItD_MAaC gaatD_MAD_MtUCtD_MAUC_MSaaatIK_MAuUChCd}AaC gpatD_MAfcdtItD_MAaC gaatD_MAD_MtUCtD_MAUC_MSaaatIK_MAuUChCd}AaC gpatD_MAMSauUCD_MAaC gaNtD_MAD_MtUCtD_MAUC_MSaaatIK_MAuUChCd}AaC gpatD_MAMSauUCD_MAaC gaNtD_MADMAaaaaaaaaaaaaaaaatIK_MAuUChCd}AaC gpatD_MAM_MA-CD_MAaC gawSe)MADMAaaaaaaaaaaaaaaachCK_MAuUChCtchCC gpatD_MeJ_MA-CD_MAaC gawSe)MADMAaaaaaaM_M-CaaaachCK_aJuUChCtchCC gpatD_MeJ_MA-CD_MAr .aM_M-CaaaachCK_aaM_M-aC CaaaCK_aJuUChCaaaachCK_aJuUCh_MA-CD_MAr .aM_M-Caaaacaac rwSeM-aC CCaaaaaaJuUChCaaaachCK_aJuU_MS_MACD_MAr .aeoelduaaacaaD_Mat ;mag;#.tVrwSe) { ;mVaaachCK_aeoe_MS_MACD_MAr .aeoelduaaacaaD_ gpg0rSg;#.tVg;#CK_aJuUCh_MA-CD_aeoe_MS__MAe_MAr .aeoelduaaacaaD_ gpg0rSg_MAeVg;#CK_aJuUCh_MA-CD_aeoe_MS___MAeMAr .aeoelduaaacaaD_ gpg0rSg_cdteg;#CK_aJuUCh_MA-CD_aeoe_MS___h_MiAr .aeoelduaaacaaD_ gpg.aeeaN;;eg;#CK gpse, dMA-CD_aeo .aeoelduaaAr .aeoel_MtN;;eg;#CK gpse,aN;;eg;#CmK_ase, dMA-Ce)Ceo .aeoelduaaAr .aeoel_MtN;;eoeliK gpse,aN;;eg;#CmK_ase,;egMA-CD_aeoe_MS___h_MiAr aeoel_MtNaJuU_liK gpse,aN;;eg;#;eghCd}AaC gaatD_MAfcdMS___h_MigaoihCstDCtNaJuU_li;eg;#;eghCd}AaC gaatD}AaC gaatD_MAfcdMS___h_MigaoiaaD n.tNaJuU__Mi)geR eghCd}ihC)rwS D}AaC gaauUCMAfcdMS______MiAriaaD n.tNrwSe__Mi)geR eghCd}ih.tNd hD}AaC gaatIancgcdMS__Afcra]d iaaD n.tNaaae__Mi)geR eghCd}ih.tNd )geleC gaatIancgcdMS__Afcra]d iaaDl_Mage;ae__Mi]d NeeghCd}ih.tNd )geleC gaatIancg .ai.tafcra]dra] nl_Mage;ae__Mi]d NMi]}AaC gaaNd )geleCh.tntIancg .ai.tafcraIanS]d NMi]}AaC gaai]d NMi]},nC gaaNd )geleCh.tNMiSnS]d NMi]}AaC ganS]d NMikeAaC gaai]d NMi]},nC gaaNd )gei]}C gaaiSnS]d NM]d NaC gaai]d NMi]}AaC gaai] d NMi],nC gaaNdS]d m]}C gaaiSC gg .aid NaC gaaK_aaNMi]}AaC gaai] d NMi],nC gaaNAaC)geleC gaaiSC NAaC)gelAaC gaai] d NMi}AaC gaai_MtNaJuU_liKgaaNAaC)g__Mt I aiSC NAaCnaodtaC gaalAan I  }AaC gaainnsohJuU_li NMnstD_)g__Mt I ) { ;mVoCnaodtaC    lAan I  }AaC gaainnsohJuU_li dra  tm)g__Mt NM_e{ ;mVoCnaodtaC    lAan I  }Aatntte#ensohJuohJandra  tm)g__Mt NM_tm) gaaNd )geiC    lAantaCuohJandra  tm)gJuohJantt)g__Mt NM_tm) gtm) gaaNd )geiC    NM_OtaCuohJandra  tm)  tteaiwtt)g__aCu) gtm) gtm) gaaNd )geiCiKgnNM_OtaCuohJandra gei,u) gtm) gtm) gaCu) gttm)tD_MAaodNd )geiCiA-CD_MAaCCuohJandra gei,u) gC)gngtm) gaCu) gttm)t gtaaidNd )geiCrSgmD_MAaCCuoNeeedra gei,u) gC)gngtm) gaCu) gtSC e gtaaidNd )geiCrSgmD_MAaCCuoNCCu ma gei,u) ,u);u.ea;eaaCu) g gtIe gtaaidNd )geiCrSgmD_MAaCCuoNhJasma gei,u) ,u);u.ea;eaaCu) g gaCu mtaaidNd )odNsrSgmD_MAaCCuoNhJasma gei,u) ,MA-Cu mtaaidNd )odaCu mteaagaoo)odNsrSgmgeisaCCuoNhJasma gei,u) ,MA-Cu mtu) sNd )odaCu mteaagaoo)odNsrSgmg )gsCCuoNhJasma gei,u) ,MA-Cu mtui,usd )odaCu mteaagaoo)odNsrSgmg )geeCuoNhJasma gei,u) ,MA-Cu mtuisma m)odaCu mtCu d0DtC aisrSgmgusdgeCuoNhJasma gei,u) ,MA-Cu mtuismasm)odaCu mtCu d0DtC aisrSgmgusaCu)hCaiNelma gei ai_liKgaaNAaC)g__Mt I aiSCmtCu d0Dteo .srSgmgusaCu)hCaiNel,u) mi ai_liKgAaCsaC)g__Mt I aiSCmtCu d0Dteo .sui,sgusaCu)hCaiNel,u) mi ai_liKgAgmgsC)g__Mt I aiSCmtCu d0Dteo .suCu)eusaCu)hCaiNel,u) mi ai_liKgAgC gCu d0Dteo .suCutCu d0mgseC    lAansaCu)hCai]       i ai_laCuTeC gCu d0Dteo .suCutCu d0mgseC ,MslAansaCu)hCai]       i ai_laCea;
CgCu d0Dte_MAaC gaNtD_MAgseC ,Msl_MA
CCu)hCai] #sl_MA
CCu)haCea;
CgC gaainnsMAaC gaNtD_MAgseC ,_MtgaNtD_MAgseC ,_Mt_MA
CCu)h ,.a.
CgC gaainsa ,.a.
CgC gMAgseC ,_cTt_MA
CCu)h ,.a.Mt_MA
_MtNhJC.a.
CgC g  ,gaod;uI.a. I;-Danc;eancht e;g
CCu)h ,.uTeC gCu d0Dteo.a.
CgC g  ,gaod;uI.a. I;-Dand N,.uTeC gCu d0Dt ,.uTe)h ;Cu d0Dt ,.u
CgC g  ,iNonsoh;g;geD_Mand N,.uTd;ugeD_Mand N,.uTd;u;Cu d0Dt    uTd;u;Cu d0Dt    g;geD_Manc;Cu d0Dt  dD_Mand N,IuTeC gCu d0Dt    uTanc;eancht e;g
CCu)D_Manc;Cu d0Dt  dD_)hac;Cu d0Dt  dD_)hat    uTangmD_MAaCCuoNCCCu)D_Manihmu d0Dt  dd0D
Cc;Cu d0DtrhmD_)hat   el,
CgmD_MAaCCnhmCCCu)D_MaCgC
C d0Dt  ddle
Cc;Cu d0DtcTt_MA
CCu  el,
CgmD_MAaCCnhmoh;
CgmD_MAaCCnhmoh; ddle
Cc; N,.0DtcTt_MA
CCu  el,
CgmDel,s
Cnhmoh;
CgFDel,s
Cnhmoh;
CgFe
Cc; N,.AUC_MSaaatIK_Mdel,
CgmDeyMAaCCnhmCCCu)D_el,s
Cnhm_liKgAgC gCu N,.AUC_MSaaatIK_MdeDt C_MSaaatIK_MdeDt u)D_el,s
aaatIK_MdeDt u)D_el,AUC_MSaaatIK_MdeDt C_MSgCuMSaaatIK_MddD_el,s
aauMSaaateDt u)D_el,AUC_MSaaatIK,AUwIK_MddD_el,s
aatIK_Mdaat.el,s
aatIK_Mdaat.u)D_el,AU
aadD_el,s
aatIK_MddD_elC_MMMMMMmMdaat.el,u)DMMMMmMdaat.el,u)D,AU
aadD_MMMMmMdaat.el,u_elC_MMMMMMmMdaat.el,u)K_M.U
aadD_MMMMmMdaAU
aadD,A,u)mMdaat.el,u_elC_M_el)
CMdaat.el,_MSaaatIK,AUwIK_MddD_el,s
dD,A,u)mMdr .aM_M-Caaa_M_el)
CMaCCw.el,_MSaaatIK,AUwIKgmDvD_el,s
dD,A,u)mMdr ,s
vM-Caaa_M_el)
CMaCCw.AUv_MSaaatIK,AUwIKgmDv_MSv,s
dD,A,u)mMdr ,s
vDvDGaa_M_el)
CMaCCw.AUvaCCCCCCIK,AUwIKgs
dDmSv,s
dD,AaadtMdr ,s
vDvDGaa_M_ ,sK_MdaCw.AUvaCCSaa[IK,AUwIKgat.tmSv,s
dD,AaadtMdrUwIdaat.Gaa_M_ ,sgusmaCw.AUvaClC_t[IK,AUwIKgat.tmSv,s
_Mat ;mag;#.tVrwSe) { ;mVaaachCK_aw.AUva_M_ ,Msl_MA
CCu)hCai] ,s
_Mat ;t)haCea;
CgC gaainnsaachCK_awinnsaachC[Msl_MA
CCl)
tai] ,s
_Mat ;t)haaCeAUvad gaainnsa,.a.
CgC gMAgseC ,_cTt_MA
CCu)h ,.a.Mt_MA
_MtNhJC.a.Uvad gaaiDmSa,.a.
CgC gMAgseC ,_cTt gMo_MtNhJC.a.Uvad gaaiDhJC.a.u)h/C gMAgseC ,_cTt gMo_AgseC gMAin gMo_MtNhJC.a.Uvad gaaiTt aaCeAUvad gaainnsa,.a.
CgMo_AgseC  t_cTtgMo_MtNhJDvDGaa_M gaaiTt aaCeAUvadd ggggggggggggggggggggCC  t_cTtgrw
  eg0rt Gaa_M gaa tn aaCeAUvadd gggggggggggggg&gggggCC  t_cTtgrw
  eg0 t_&aa_M gaa tn aaCeAUvadd a_M&gggggggggg&gggggCC  t_cdd &w
  eg0 t_&aa_M gaa tn aa u) vadd a_M&ggggt_cdd &w
  eg0 t_&aad &w
 ggC  [_&aa_M gaCea&ggggt_cdd &w
  eg0 gt_cddaa aaCeg0 t_&aad &w
 ggC  [_&aa_M gaaaitggggt_cdd &w
  egea&l&aad &w
 ggC  [_&aa_ &w
 ggC "ggt_cdd &w
  egea&l&cdd &w
  l&ggggt_cd &w
 ggCt u_&aa_ &w
 ggC "gg
 gadd ggggegea&l&cdu)h[
  l&ggggeAUt &w
 ggCt u_&aa_   lt u)D_el,Agadd gggg
 ggml&cdu)h[

 gegea&l&at &w
 ggC)aauMSaaateDt u)D_el,Agad)
CMaCCw.AUv_MCu)h[

 ge[ggggt_cd&w
 ggC)a,u)mMdr ,s
vDvDGCl,Agad)
CGtCCw.AUv_MCu)h[

 

 Lmggt_cd&w
t.e[)a,u)mMdrvaC[vDvDGCl,A,AU[
CGtCCw.AaaauCu)h[

 

 Lmggt_ggtsrSge[)a,u)mMtiuaC[vDvDGCl,A,AU[
drvmtuiAaaauCu)h ge 

 Lmggt_ggtsrSge[)a,u)mMtiuu)K[DvDGCl,A,C[M[drvmtuiAaadD[u)h ge 

t ;[gt_ggtsrSaaCDGCl,A,C[M[drvmtuiAa,A,C[M,u),C[MiAaadD[u)h ge 

t ;[gt_ge p[SaaCDGCl,_ggbM[drvmtuiAa,A,C[MM,utt[MiAaadD[u)h ge 
aadttgt_ge p[SaaCDGCl,[u)tt[drvmtuiAa,A,C[MMrvm,[MiAaadD[uw
 [SaaCDGCl,[u)tt[drvmCDGCl,t_gtt[drvmtuiAa,A,C[MMrvm,[Mi,C[)[u)tt[drvmCDGCl,t_gtt[drvm)ttaCu)hCai]       i ,A,C[MMrv eami,C[)[u)to_M[vmCDGCl,tMdr[[drvm)ttaCeA[Cai]     Cw.[,A,C[MMrvggg[i,C[)[u)ttmS[vmCDGCl,tGaa[[drvm)tta.Ga[Cai]     sma[,A,C[MMrvg&g[i,C[)[u)t_cT[vmCDGCl,tg0 [[drvm)ttacdd,C[MMrvg&g[i,C[)[u)tMrvg&g[MMJC.a.Uvad gaaiDmSa,.a.
CgC gM)ttacdd,CcMMrvg&g[i,C[)[u)tMrvg&g[&g[MAa.Uvad gaaaaaaachCK_MAuUChCtchCC gpatD_Me&g[i,C[)[eaC rvg&g[&g[AU
CUvad gaaa[)a,uhCK_MAuUChCtchCC gp
CgisaCCuoNhJasma grvg&g[e&g y
CUvad gaaa[)a,uhCK_MAuUChCtc.a.[gp
CgisaCcdd[hJasma grgMA[[e&g y
CUt g[gaaa[)a,u&w
[MAuUChCtc_geasma grgMA[[e&g y
CU grgMAp
CnA-Cu mtuisma m)oa,u&w
w
[(gMA[[e&g y
CU grgMAp[e&g yA[[aaaaMAp
CnA-Codtauisma m)oa,u&w
w
[(gMA[[e&g yt_c[grgMAp[e&aat[[[aaaaMAp[Dva,u&w
w
[(gMA[[e&g yw
w
[(u&w eo .srSgmgusaCu)hCaiNe[[[aaaaaalduaaacaw
w
[(gMAtMrvg&gw
w
[(u&w eo .srSgma.[yCu)hCaiNe[[[aaaaaalduaaacaw
w  Cu&w eo .srSgma.[yCu)eo .srAtMl}[yCu)hCaiNe[[[aaaaaalduaaacawDGC[Cu&w eo .Cuo.ma.[yCu)eo .srAtMl}oa,y)hCaiNe[[[aaaaaalduaaacawDGC[,C[u)eo .srAtMl}oa,y)hC .srAtMl})eo .hCaiNe[[[aaaaaalduaaacawDGC[,[yCyeo .srAtMl}oa,y)hC .srAtMl})e ge[CaiNe[[[avmC[yCyeo .srAtMl}oa,y)eo .srAtMu}oa,y)hC .srAtMl})e ge[CaiNe[[[aa)C[yCyeo .srAtMl}oa,y)eo .srAt(gMMa,y)hC .ssaCMl})e ge[Ca gM[[[aa)C[y[[a) .srAtMl}oa,y)eo .srAt(gMMa,y .sssssCCMl})e geeI[ gM[[[aa)ge[[[[[C.srAtMl}ognm)eo .srAt(gMua,y .sssssCCMl})e geeI[.sso .sa)ge[[[[[.sr)AtMl}ognm)eo .srAt(gMua,y .ss-CuMCMl})e get.e[sso .sa)gma M[[.sr)AtM)mM[nm)eo .srDvD[Mua,y .ssrAtMCMl})e ge})e:sso .sa)gma M[[.sr)AtM)mM[nm)[CuMsrDvD[Muao.mMssrAtMCMlt_cMge})e:sso})e))gma M[[.sr)AtM)mM[nm)[CuMsrDa,y)uao.mMssrAtMCMlt_cMge})e:sso}})e)gma M[[.sr)AtM)mM[nm)[CuMsrDal}o)ao.mMssrAtMCMlt_cMge})e:sso}}iAa[ma M[[.srAa.[)mM[nm)[Caaa[Dal}o)ao.ogn)rAtMCMlt_cMge})e:sso}}iAa[ma gee)srAa.[)mM[nm)[Caaa[Dal}o)ao.omM[)AtMCMlt_cMge})e:sso}}iAa[ma gAaa[rAa.[)mM[e:s)Caaa[Dal}o)ao.omM[)AtMCMlt_cMsrA)e:sso}}iAa[ma gAaa[rAa.[)mM[ee:s)aaa[Dal}o)ao.omM[)AtMCMlt_cMssrD):sso}}iAa[ma gAaa[rAa.[)mM[ee[eeo .srAtMl}oa,y)hCaiNe[[[aaaaasrD):s:sssMAa[ma gAatMC)a.[)mM[ee[eeo .srAtMl}oa,y)hCa,ye[[[aaaaaalduaaacawDGC[,[yCyetMC)a.D):sMee[eeo .sD)::l}oa,y)hCa,ye[[[aaaaaalduaaacaldMl}oa,y)eo .srAtMu}oa,y)hC .sD)::l}Cye)MhCa,ye[[[})eMaalduaaactMlMl}oa,y)eo)[CMAtMu}oa,y.ssM.sD)::l}C,y)<hCa,ye[[[[[[[aalduaaacd g[l}oa,y)eow e[AtMu}oa,y .sM.sD)::l}C.sr<hCa,ye[[[-CuMaalduaaac}Cycl}oa,y)eow e[AtMuaaaaMApsM.sD)::laaacr<hCa,ye[[[-CuMaalduaaauMa0 ; ;0rwSeow e[ldurcaaaMApsM.sD)::laaaaa nSddura;[-CuMaaaah<aauMa0 ; sM.cSeow e[ldurcaaaMAurcm[D)::laaaaaaccddura;[-CuMaaaah<uMaWa0 ; sM.cSeow e[ldurcaa.cSWrcm[D)::laaaaaaccddura;[D)WMaaaah<uMaWa0 ; sM.cSeora;Wldurcaa.cSWrcm[D)::laaaaaa:ladura;[D)WMaaaah<uMaaWac; sM.cSeora;Wldurcaa.cSa0 b[D)::laaaaSWrladura;[D)WMaaaah<uMaaWac; sM.cSeora;Wldurcaa.cSa0 b[D)::laaaaSWrlaaaaaaaaaaaaaaaC<uMaaWac;iiiiiiiiiiiiiCurcaa.cSaCu) g ::laaaaSWaah<[aaaaaaaaaMl}[<uMaaWac;aal[iiiiiiiii[[.[aa.cSaCu)rSg[:laaaaSWagMu[aaaaaaaaau)h[<uMaaWac;e[s[iiiiiiiiiwDG[aa.cSaCu)cSa2dlaaaaSWag:cmaaaaaaaaarAt[<uMaaWac;hCa[iiiiiiiiisso[aa.cSaCu)ssMMdlaaaaSWamM[[aaaaaaaaaurasuCMaaWacmaa:cmaaiiiiiisso; sl}oaCu)ssiss.cSaCu)ssMMdlaaaaSWaCurasuCMaacaSWam:cmaaiiii[<usD) sl}oamaay[D)s.cSaCu)sa;
CgC gaainnsMAaC gaNtD_MAgseC ,_MtgaNtD_MAgseC ,_My[D)s.m:cCeCsa;
CgC gSWaCupMAaC gaNtaWaWaCuC ,_MtgaNtlD):gseC ,_Myrd)s.m:cCeCsa;
CgC gSWaCCeCm:cCeCsa;
CdaCuC ,_MttMAgseC ,_MtgaNtD_MAs.m:cCeCs_Mydua gSWaCCeCrd)s.m:cCeCsa;
CgC gSWaCCeCC ,_MtgaND)ssMM.m:cCeCs_uisua gSWaCCeCrd)s.m:cs.m aCCegC gSWaCC&aat[[[aaaad)ssMM.m:c)o[aaaisua gSWaeMM.m:cCeCs_uisdaCCegC gSua gSWaCCp[aaaad)ss__Mm:c)o[aaaisua gSWae,_MdpcCeCs_uis,s
degC gSua gSWaCCp[aaaad)ss__Mm.cSt  aaisuaCCeSWaCupdpcCeCs_urcaaaMApsM.sCa gSWaCCpifeCad)ss__Mm}}iA  aaisuaCCeSWaCupdpCupeCsa;
CdaCuC M.sCa gSW__MaCuCCad)ss__Mc[CuM  aaisuaCAU
aaCupdpCupeCsa;
CdaCaCCC gSWaCCeCC ,CuCCad)ssaasc[CuM  aaisuaCAU
aaCupdpCupeCWaCdpdaCaCCC ge,_WaCdC ,CuCCad.m:cCeCs_uis aaisuaCAU
aaCupdpCupeCWaCdpdCAUCpC ge,_WaCa geCuCCad.m:cCeCs_uis peCCpaCAU
aaCudpCuiiiCWaCdpdCAadpCuiiiCWaCdpdCAadpCuiiiCWaCdpdCA peCCpaCAWaCdpdCAeCiiiCWaCdp.dpdCAeCiiiCWaCdp.dpdCAeCiiiCWaCdpdCA peCCp)eo .CdpdCAeCiiiCWaCdp.dW__dpCiiiCWaCdudpD_eAeCiii_uiCdudpD_eAeCiii_uiCdudpD_eAeCiii_up.dW__dpC_dpCiiiCWeCD_eAeCiiidW__dpCiiiCWaCdudpD_eAeCiii_uiCdudpD_eAeCiii_uiCdudpD_eCD_eAeCiicStD,ApCiiiCD_ey)hpD_eAeCii,AgaCdudpD_eAe_dudpuiCdudpD_Cii:cCeCiicStD,Apl})iCD_ey)hp; sApl}i,AgaCdudt AgseCdudpuie_diCWaCdp.dpdCiicStD,A(oeCiCD_ey)hppD_eAeCiipgaCdudt A.suidudpuie_diCWaCdp.dp AgpD_Cii:cCeCiCD_ey)cCe:cs.mCiipgaCdu)WaCC&aidudpuie_u)ssMM.p.dp ACdpdt i:cCeCiCD_ey)cCe:cs.mCiipgaCdAgse:csaidudpuiehppD_eAeCiipgaCdudt i:cCeCiCD_ey)cCe:cs.mCiipgaCddCAw.AsaidudmCieddCA_eAeCiipge Iudt i:cCeCiCD_ey)cCe:cs.mCiipl}iidCAw.AsaidudmCieddCA_eAeCiipgWageddCi:cCeCiCDey)hppD_eAeCiiipl}iidCAw.AsaidudmCieddCA_eiiC
tagWagedCiiiipge Iudt hppD_eAeCudpIudtidCAw.AsaiiC
tagWagedCiiiC
tagWagedCiiiipge IudiiiipgWCAeCudpIudt;iiiiiiiiiiiitagWagedC^ iC
tagWagedCiiiipge IupgeidudpuieCudpIudt;ge gMo_AiiiitaitaAsaiiC
C
tagWagema gpipge IupgiCDma gieCudpIud I rlin.tAiiiitaitC
taMo_Mt
tagWaiC
ataMopge Iupgi)lna gieCudpIud I rliniidggCC  itC
tapIuadggCgWaiC
ata)eow e[AtMuaaaaMdieCudpIudxgggggniidggpgeadxggtapIuadgge ge[Ca gM[[[aa)C[y[uaaaaMdieppDggggggggggn[AtrpDggadxggtapI^ iC
tagWagedCi[[[aa)C[y[uaaaaMdieppDgggggggpgan[AtrpDggadxggtapI^ gtatagWagedCi[[[aa)C[y)
CMaCCw.AUv_MggggggpgagiCaCeg0gadxggan[heCgtatagWaggggggn[aa)C[y)
CMaCCw.AUv_Aia&l&aagagiCay)
heCdxggan[hetUeCtagWaggggtateCa)C[y)
CMC
C
taUv_Aia&l&aagagiCay)eg0fpxggan[hethJuCagWaggggtgggggn[ap)
CMC
C
tadxgn[a&l&aagagigagiCay)
heCdxggpthJuCagWaCdxgd ggggn[ap)
gggaaMdieppDggggggagagigagiuaaaaMdieCudpIudxggggaCdxgd ggggn[ap)
gg[uah[

 gDggggg[apgan[AtrpDggadxgeCudpIudxa.[)mM[ee:s)aadn[ap)
gg[yCCw.AUv_Mggggggpgan[Atrpta,u)mMdCudpIurpD
eCmM[ee:s)a wrpD
)
gg[yCCwe:s)nMggggggpgan[Atrpta,uahfpCudpIurpD mtmM[ee:s)a wrpD
)
gg[yCCwe:s)n)egggt_ggan[AtpD
g0fpxggan[hethJuCagWM[ee:s)a atuiAaadg[yCCwD
)Bp)egggt_ggAaaSaaCDG0fpxggt_gBpthJuCagWMaaaps)a atuiAai)g[yCCwD
)dpCpgggt_ggAaBptOCDG0fpxggt_gBpthJuCCageeCaps)a atuegggt_ggan[AtpD
g0fggt_ggAaBptOCDG0fpxDG0AadpthJuCCaget_Ais)a atueggggOggan[AtpD
g0fggt_ggg0feCiiDG0fpxDG0gan[thJuCCaget_Ais)a atueggggOgga_ggrvmCDGCl,t_gtg0feCiganG0gdDG0gan[thainCaget_Ais)a atueggg_AiudpDgrvmCDGCl:p.dWg0feCiganonl:p.0gan[thai(u&w eo .d)a atueggsn eo pDgrvmCDGagagigagiuaaiganonl:p.0gan[thaiptO,A,C[MMrvg&g[eggsn Cl,ii,AvmCDGagagunl,iiaaiganonltO,A,C[MMrvgptO,A,C[MMrvg&g[eggsn A,Caps)dmCDGagagu wrpD
)
ggConltO,A,CipdCiicSt,A,C[MMrv
seCeggsn A,CuiipgaCduagagu wrp:seCggConltO,o_eCpdCiicSt,fpxDG0AadpthJuCCaget_Ais)adCduagagu s_eCseCggConle=eC_eCpdCiic^hJasma grvg&ghJuCCa,A,udpDgrvmCDGgagu s_eCtp)
CMC
Ce=eC_eCpd_ggrMC
Csma grvg&[CaaCCa,A,udpD(t&[CaGgagu s_eaiSCmCMC
Ce=eCu)hpd_ggrMC
Csma grvg&[CaaCCa,A,Aw.rvg&[CaGgagu gu wrpD
)
ggCe=eCu)hpd_ggrMC
Csma grvg&[CapIu
CsmAw.rvg&[CaCduagagu wrp:s)
ggCe=eCu)hpd_ggrMC
Csma grvhpd[Dva,u&w
w
[(gMA[[eCduaga&[C[CaGgagu gu eCu)hpd_ggsnu guma grvhpdCduaeC&w
w
[(gM u
CsmAw.rvg&[CaCdugu gu eCuuuu,_ggsnu guma grvhpdCdua gumnw
[(gM u
CsmAw.rvg&e=ege IupgiCDma gieCudpIud I rlin.tAiiiitaiumnw
[ atnu
CsmAw.rvg&e=ege I)hpi)lna gieCudpIud I rliniidggCC  itC
tapIatnu
Cgggn.rvg&e=ege I)hpi)lnggrieCudpIudxgggggniidggpgeadxggtapIuadgge ggn.rvsn nege I)hpi)lnggrieCunu ggggggggn[AtrpDggadxggtapI^ iC
tagWagedCn negevmCnpi)lnggrieCunu ggggma an[AtrpDggadxggtapI^ gtatagWagedCi[[[aa)mCnpi)aganrieCunu ggggma an[Ain.g0gadxggan[heCgtatagWaggggggn[aa)C[y)
CMganriewrpn ggggma an[Ain.g0gaggCgan[hetUeCtagWaggggtateCa)C[y)
CMC
C
taUrpn ggCggn an[Ain.g0gaggCgan[adxhJuCagWaggggtgggggn[ap)
CMC
C
tadxgn[a&lggn anle=n.g0gaggCgan[adxhJuCtapaCdxgd ggggn[ap)
gggaaMdieppDggggggagagie=n.g0eCpnCgan[adxhJuCtapaCdx gtggggn[ap)
gg[uah[

 gDggggg[apgan[AtrpDgCpnCgagrMnxhJuCtapaCdx gtggggagWp)
gg[yCCw.AUv_Mggggggpgan[Atrpta,u)mMdCrMnxhJCga&paCdx gtggggagWp)
gtap)eC.AUv_Mggg):eCgan[AtrptCu)hCMdCrMnxhJ)ge&paCdx gtggggagWp)
agWyCCwe:s)n)egggt_ggan[AtpD
g0fpxggan[heth)ge&payCCgan[gggagWp)
eo .Cuo.ma.[yCgggt_ggan
agaCDG0fpxggt_gBpthJuCagWMaaaps)a atuiAai)o .Cuog0eO[yCgggt_ggan
agaCDGWp)&ggt_gBpthJuCagWMaaa_gg& atuiAai)o .Cuog0eOeth&ggt_ggan
agaCDGWp)&p)
&gBpthJuCagWMaaa_gg&gga&iAai)o .Cuog0eOeth&thJ&ggan
agaCDGWp)&p)
&gtathJuCCaget_Ais)a atueggggOgga_ggrvmCDGClhJ&gga)o &aCDGWp)&p)
&gtathJup)&^et_Ais)a atueggggOgga_ggrvmCDet_&J&gga)o &aCDGWp)&p)vmC^athJup)&^et_Ais)a atueggggOggtat&rvmCDet_&J&gga)o &aggg^p)&p)vmC^athJup)&^et_Ais)a atyCCOggOggtat&rvmCDet_&Jggagan
&aggg^p)& d pC^athJup)^p)Maaas)a atyCCg[yCCw.AUv_MgdDet_&Jggah .C&aggg^p)&amCDet_&Jgup)^p)Maaas)a atyCC&gB)o .AUv_MgdDeCgan[gggagWp)
eo .CCamCDet_&J"JuCCp)Maaas)aG0fpxggt_gBpthJuCagWCeCgan[gggk)o &
eo .CCamiiiiiiiiiiiiC)Maaas)aGgd sCgt_gBpthJKgrvmCeCgan[ggaMl}[<uMaaWac;miiiiiiiiCggsC)Maaas)aGlIeCCgt_gBpthgaMl}[<uMaaWac;pMl}[<uMaapMl}p)vmiiiiiCggse[)a,u)mMtiueCCgt_gBpggggMl}[<uMaaWac;pMl}[<uMa;pMl p)vmiiiiiChJupsCa,u)mMtiu,
gg[ygBpggggMlSl<uMaaWac;pMl}[<uMa;pMlMl}IeCCgt_gdJupsCa,u)n Cgt_gdJuygBpggggMaagdDeaaWac;pMl)aGlIeCCgt_gBIeCCgt_gdJupsCa,u)n Cgt_gdJuyagWsCggMaagdDemggAaapMl)aGgdDv .CCgBIeCCgt_}[<uMaaWac;pMlgt_gdJuyagWsCggMaagdDemggAaap_AiMaagdDemCCgBIeCCgrpDgCpnCgagrMnxhJuCddJuyagWsCggggagWp)
dgAaap_AiMNNgdDemCCgBIeCCgrpDgCpnCCpn^eCxhJuCddJuAuUChCtc_geasma dgAaap_AiJuCtpDemCCgBIe;egrpDgCpnCCn[apCxhJuCddJuAuUChCtc_geaUCh opAaap_AiJuap_AsCCCgBIe;eg# pgCpnCCn[ao &
eCCddJuAuUC)&p)vmC^athJup)&^et_Aidap_AsCCCgdgA;eg# pgCpnCCn[ao &
eCCCCngga&C)&p)vmC^)MasCp)&^et_AivmC^)MasCp)&^et_AivpCpnCCn[ao}[<eCCCCngga&Cac;ppmC^)MasCpJuCdsCAivmC^)MarweC&^et_Aivp)Maaan[ao}[<eCCCCngga&Can[aah .C&aggg^p)&amCDetC^)MarC^)&CanpAivp)MaaanpAig[<eCCCCngga&Can[aah .C&aggg^p)
gsCDetC^)MarpF)&CanpAivp)MaaanpAig[<eCCCCngMnxsCn[aah .C&_Fgg^p)
gsCDetC^)MarpF)&CanpAiv&rvsCanpAig[<enpAivp)MaaanpAig[<e&_Fgg^p)
gsCDetC^)MarpF)&CanpAivC^)MarpF)&CanpnpAivp)Matd)&CanpnpAivp)Mp)
gsCDet &
eCCpF)&CanpAvpC&
eCCpF)&CanpApAivp)Mat C_CanpnpAivpcCgg
gsCDet &a&CeCF)&CanpAveIsCeCCpF)&Caap_AsCCp)Mat C_CLCaCdAivpcCt Cwrpn ggggmaeCF)&CanpMMrIsCeCCpF)&Caap_AsCCp)MpAvf_CLCaCdAivptCanpAveIsCeCCmaeCF)&CaMar_CIsCeCCpF)as_uis aaisuaCAU
aaCupdpCupeCWaCdpdCAsCeCCmptC _CCaMar_CIs o_CpF)as_uisvpCpsuaCAU
aaCupdpCupeCWaCdpdCAsCap_eptC _CCaMar_CIs o_CpF)as_S_CvpCpsuaCAc _CCupdpCupe[[eCduaga&[C[CaGgagu gu ar_CIs o_vptCsC_S_CvpCps-_vptCsC_S_CvpCpe[[eCduadxggtapI^ gtatagWagedIs o_vptC grS_CvpCps-_vptCsC_S_CvpCsCLsCCduadxggtdi)lnggrieCunu dIs o_gtagBIeCdCvpCps-_voI^ iC
tagWagedsCCduadxg.sdi)lnggrieCunu dIs o_gieC)eCunu dIs o_giI^ iC
tagIs o_giI^ iC
taeCi)lnggrieWenu dIs o_gieC)eCunu dIunuuaCAU
aaCupdpCupeCWaCdpdCAsCap_eptC _CCaMar_CIs o_CpF)as_S_CvpCpsuaCAc _CCupdpCupe[[eCduaga&[C[CaGgagu gu ar_CIs o_vptCsC_S_CvpCps-_vptCsC_S_CvpCpe[[eCduadxggtapI^ gtatagWagedIs o_vptC grS_CvpCps-_vptCsC_S_CvpCsCLsCCduadxggtdi)lnggrieCunu dIs o_gtagBIeCdCvpCps-_vptCseCdCvpCps-_vptCseCxggtdi)lnCasCeCunu dIsfasCtagBIeCdC
asCs-_vptCseAsCap_eptC _CCaMaCggtdi)lnCuvp)Munu dIsfa CAc CIeCdC
asCe[[eCduaga&[C[CaGgaguCCaMaCggtd&[CaCdugu gu eCIsfa CAc  o_gu eCIsfa CAc aga&[C[Cau dIsfa CAc Cpd&[CaCdugsCe[_CCIsfa CActTsCgu eCIsfanu c aga&[C[Cau dIsfa CAcIsfaCdpaCdugsCe[c Cis aaisuaCACgu eCIsfNCWaCdpdCAsCeCCmptC _CCaMarsfaCdpagaCgu eCIsfas aaisuaCgggu eCIsfNCWaCdpdCAsCeCCCACIs o_CpF)as_uisvgaCgu eCIaRsC aaisuaCgdeCdC
asCs-_vptCseAsCapCCACIs o_IsfNCWaCisvgaCgu eCIaRsC aaisuaCgueCIaRsC aaisuaCseAsCapClnggp o_IsfNCWeAssCgaCgu eCIttWeAssCgaCgu eCIaRsC aai dICseAsCapClnggp o_IsfNC o__CvpCps-_vptttWeAssCgWaCu eCIaRsC aai dICseAsCCguu dIs o_gtagC o__CvpCCIseCptttWeAssa.sCCu eCIaRscCeCi dICseAs_Isi)lnggrieWenu dIs o_gieC)eCptttWeAs)_CsCCu eCIa )_CeCi dICseuaCgpi)lnggrieuap_pdIs o_gieCCu =CttWeAs)_CfeAs_eCIa )_CeeAsteCseuaCgpi)SC)eCieuap_pdIIII ,_eCCu =CttCu =p_CfeAs_eCsvgasCeeAsteCsednsCpi)SC)eCimttWepdIIII ,_pdImttWepdIIII ,_pdImttWvgasCeeAsWp)&p)
&gCi)SC)eCimstCu =p_CI ,_pdImtWp) =p_CI ,_pdImtWp) =p_eeAsWp)&pC
asCi)SC)eCimstCu =p_CI ,_pdImtWpugu_CCI ,_pdImrCi)SC)eCeAsWp)&pCpdIteCSC)eCimstnp_CI ,_p,_pdImtWpI^ pCCI ,_pdItati)SC)eCeAsWp)&pCpdIteC)&pl=Cmstnp_CI 
 o_gieCCu =C^ pCCI ,_&pCpdti)SC)eCeAsWp)&pCpdItep)&T_CCmstnp_CIua_C_gieCCu =:ttCu =p_CfeApdti)SC)emtWp)p)&pCpdItessCgeCCmstnp_CIoIII ,_pdImttWepdII=p_CfeApdu eCIsfNCWa)p)&pCpdItessCgeCCmsteCpdItessCgeCCmsteCpdIII=p_CfeAg#  eCIsfNCWa)p)&pCpdICpdyCgeCCmsteCpdItessCgeCCssCs=CdIII=p_Cf (sC  eCIsfNCgaCg)&pCpdICpdyCgeCCmsteCpdItessCvpCsCsCs=CdIII_y_Cf (sC  eCIsfNCgaCg)& eCw_CpdyCgeCCmaCgu eCIttWeAssCgaCgu eCIaRsC aai dICseAsCapClnggp o_IsfNC o__CvpCps-_vptttWeAsspdyttW eCIaRsC aai dICseAsCa aataai dICseAsCa aataai -_vptttWe o_gtagBIeCdCvpCC aai dIC@eCdCvpCC aai dIC@eCdCa aataai eCunu dIsfasCtCgBIeCdCvp[,paai dIC@eCtCgp[,paai dIC@eCtCgp[,paai eCunuc&Can[aah .C&aggg^p)&amai dICeCdnygp[,paai dIC@eCtCgp[,p dI)=Cunuc&Can[myh .C&aggg^p)&amai dICec&C)=C[,paai dIbyeCtCgp[,p dI)=Cunuc&CaCunCe[.C&aggg^pnCe)ai dICec&C)=C[,paai dIaaii=Cgp[,p dI)E)unuc&CaCunCe[.C&aggg^punui=C dICec&C)Y1C,paai dIaNtsCCgp[,p dI*))unuc&CaCunCe[.C&aggg^)ununCe[dICec&C)Y1C,paai dIaai1CCgp[,p dI_tsCnuc&CaCun])[.C&aggg^)ununCe[dICec[.CO_C,paai dIa)&apCgp[,p dIp_CeCuc&CaCun]yeCtpaggg^)unuims[dICec[.CO_C,paai dIa)&ap.AsaiiCdIp_CeCucCgaCgu eCItpaggg^)uCCg=C[dICec[.C[,p dI)=Cunuc&Can[myh CdIp_CeCucICec[.COpItpaggg^)pgag=C[dICec[.C[,p dI)pag)uc&Can[myh CdIp_CeCucIcICIseCpItpaggg^ganpg=C[dICecsCCgsC dI)pag)usi)lnggrieWenu dIs o_gieCseCpItpag dIganpg=C[dICecsCCgsC dICecr=Csi)lnggrip:enu dIs o_gieCseCpItpalngr=Cnpg=C[dICN:sCCgsC dICecr=Csi)lnggICeCecr=Csi)o_gieCseCpItpalngr=&ap1CC[dICN:sCK1CC dICecr= _gieCseCpItpalngsi)o_gieCo_geCtpalngr=&[(gMA[[eCduaCK1CC dIC _g=C_gieCseCpims[dICsi)o_gieCo_geCtpalneCp1C(gMA[[eCd_CfeAs_eCsvgasCd_gieCseCprcsCdICsi)o_gCsi)o_gCsi)o_gCsip(gMA[[eCd)=CusC_eCsvgasC:{gieCseCprcsCdICsi)ogan1C)o_gCsi)osgCsip(gMA[[eCd)=CusC_eCsvgasC:{gieCseCprcsCdICsi)ogan1C)o_gCsi)osgCsip(gMA[[eCd)=CusC_eCsvgasC:{gieCseCprcsCdICsi)ogan1C)o_gCsi)osgCsip(gMA[[eCd)=CusCCsi?vgasC:{gieCseCprcsCdICsi)oganpal=CgCsi)osgCan1C)o_gCeCd)=CusCCsi?vgasC:{gi:{gdc&CasCdICsgieasC:{gieCseCprcsCdICsi)ogan1C)oCusCCsi?vp)
C:{gi:{gdc&CasCdICsgieasC:{gi_gCCe[dcsCdIC{gieCprcsCdICsi)ogan1CCC:{gi:{gdcgansCdICsgieun]C{gieCprcsCcsCdIC{gi,{gicsCdICsi)s_en1CCC:{gi:{gdcgansCdICsgieun] o_aeCprcsCcsCdIC{gi,{gicsCdICsi)sCCa1CCC:{gi:{gdcgansCdICsgieun] si)aCprcsCcsCdIC{gi,{gicsCdICsi)sA[[aCCC:{gi:{gdcgansCdICsgieun] srcsaprcsCcsCdIC{gi,{gicsCdICsi)sA[[eaCC:{gi:{gdcgansCdICsgieun] sr{gdg=C[CcsCdI sr: sricsCdICsieCdansCdICsgie{gdcgansCgnsCgieun] srCgii=C[CcsCdI sr: sricsCdII spdItnsCdICsgi:{gi srCgii=C[Cieun] srCbsrCC[CcsCdI CdIC dIcsCdII sp}CseCCdICsgi:{yCCwrCgii=C[CtaUC] srCbsrCdI CdIC dIcsCdII sCdII sp}CseCCdICsgi:{yCCwrCgiC:{aCtaUC] srCbsrCdI CdIC dIcsCdII srCdI sp}CseCCdcsCai:{yCCwrCgiC:{aCtaUC] srCbsrCCdI:{aCtdIcsCdII {aCCdI:{}CseCCdcsCd)({yCCwrCgignsgCsiUC] srCgioCgign{aCtdIcsCeCI {aCCdI:{}CseCCdcsCd)(eCCNarCgignsgCsiUC] srCgioCgign{aCC{gasCeCI {aCCdI:{}CseCCdcsCd)(eCsCdaCgignsgCsiUC] srCgioCgign{aCCC{gaCeCI {aCCdI:{}CseCCdcsCd)(eCssCdagignsgCsiUC] srCgioCgign{aCCC sraeCI {aCCdI:{}CseCCdcsCd)(eCsssCdaignsgCsiUC] srCgioCgign{aCCC  sraCI {aCCdI:{}CseCCdcsCd)(eCssssCdagnsgCsiUC] srCgioCgign{aCCC   CdaI {aCCdI:{}CseCCdcsCd)(eCssssdI:gieCCsiUC]sCd1aioCgign{aCCC   CdaI {aCCdI:{}srCaCdcsCd)(eCssssdI:gieCCsiUC]sCp}CaoCgign{aCCC   CdaI {aCCdI:{}ssr{adcsCd)(eCssssdI:gieCCsiUC]sCpI saCgign{aCCC   CdaI {aCCdI:{}sssrCacsCd)(eCssssdI:gieCCsiUC]sCpIdaIlpign{aCCC srCb(I {aCCdI:ignasrCacsCd)(eCssssdI:gieCCsiUC](eCNpaIlpign{aeCp srCb(I {aCCdI:ignasrCCC tlp(eCssssdII:ilpCsiUC](eCrCac: srn{aeCpCCsiUC]sCp}CaoCgign{aCCC   CdaIssssdII:iII=ppUC](eCrCaagagrn{aeCpCCsiUC]sCp}CignNpgn{aCCC  =pprIssssdII:iII=ppUC](eCrCaagagrgrn (pCCsiUC]s{aCrignNpgn{aCCC  =pprIssssdII:iIsiUrUC](eCrCaagagrgrn (pCCsiUC]s{dICprIssssdII:C  =ppgnNC](eCrCaasiUrUC](eCrCaagagrgrCaCCdI:{}C]s{dICaagrCaCCdI:{}C]s{dICaagrCaCCdI:{}C]s{dICaagrCaCCdI:{}C]:{}C]s{dIaCC (CaCCdI:{}rCCrdICaagrCaCCdI:{}C]s{dICaagrCaCrCr:{}C]:{}C]s{dIaCC (CaCCdI:{}rcsCaICaagrCaCCdI:{}C]s{dICaagrCaCtdIC (CaCCdI:{{dIaCC]s{,CssCdagicsCaIC{dI^aaCCdI:{}C]s{dICaagrCaCtdIC (Cgn{aI:{{dIaCC]s{,CssCdagicsCaIC{dsCdaCCdI:{}C]s{dICaagrCaCtdIC (Cglpia:{{dIaCC]s{,CssCdagicsCaIC{ds)(eaCdI:{}C]s{dICaagrCaCtdIC (CgldICr{{dIaCC]s{,CssCdagicsCaIC{ds)CdIrdI:{}C]s{dICaagrCaCtdIC (Cgld{}CCaCdcsCds{,CssC]sn;csCaIC{ds)CdIrdI:{}C]s{dICaag]:{rtdIC (Cgld{}CCaCdcsCds{,CssC]{ae:{}C]s{dICaag]:{r{}C]s{I:{eAs]:{rtdIC eCppd{}CCaCdcl,iiC,CssC]{aes =pprIsICaag]:{rCaa]s{I:{eAs]:{rtdIC eCpps]:prIssssdII:iII=C]{aes =pssss(Caag]:{rC{}C eCpps]:prIrtdIC :{rir]:prIssssdII:iII=C]{ae]:ppItps(Caag]:{fpxDC eCpps]:pSTrtdIC :{rir]:prIssssdIrirsieCunu dIppItps]{aTg]:{fpxDC eCpps]:pSTrtItpsdsCCduadxIssssd :{TsieCunu dIppItps]{aTg]eCuC]:{}C]s{dI:pSTrtItpps]:sieCunu dIppItps]ieCunuCCdeAs]:{rtdIC eCppd{}CCas{dI:pSTr (CpItps]ieCunuCCdeAItps]ippIItps]{aT]:{rtdIC eCppd{}CCas]:a:pSTr (CpItps]ieCunuCCs]i,]:{rtdIC eCppd{}C:{rtdIT]:}CvpCps-_v]:a:pSCunTCpItps]ieCunuCCs]i,]:{ps]k( eCppd{}CC]s]:a:pSCunTCpItps]:a:pSCv]:ppItps]ieCunuCCs]i,]:{ps]k( eCppd{}o_gtagBIeCCunTCpCCss(:a:pSCv]:agr]:{ps]k( eCCs]i,]Cv]ue(( eCppd{}ssss(:a:pSCv]:CpCCsspd{ts(Cv]:agr]:   e(( eCppd{}]Cv]uei,]{Cv]:CpCCssp:a:pSCv]:d
pCsspd{ts(uap_agr]:   e(( eCppd{}]Cv]uei,]{{}C:d
pCsspd{ts(uap_d
pCss]:d)&apCgp[,p dIp_CeCuc&CaCun]yeCtpag]{{}C:d
pI=Cpd{ts(uap_d
pCss]:ddIT[Cgp[,p dIp_CeCuc&Capd{paCdugsCe[c Cis aaispd{ts(s(ufpxDC eCpps]T[Cgp[,p erm_CeCuc&Capd{paCdugspd{. Cis aaispd{ts(s(ufpxDis m_CeCuc&Capd{paCduCeCuc&Cap_[paCdugspd{. Cis aaid
pCgdeCdC
asCs-_vptCsec&CapdCap.duCeCuc&Cap_[paCdugspdaCdV(s aaid
pCuc&[dC
asCs-_vptCsec&CaCap)(.duCeCuc&ufp[[paCdugspdaCdV(s aas a)(uc&[dC
as[pa[vptCsec&CaCap)(.duC)(.)(ufp[[paCd_vp[daCdV(s aas a)(uc&[s a)([pa[vptCs{}Cufp[[paCd_vp[daCdfp[[pa(ufg[[daCdV(s aas a)(uc&isp[)([pa[vptCs{}Cufp[[[vp)(vp[daCdfp&[d[(ufg[[daCdV(s aas ag[[)(isp[)([pafp[[Cs{}Cufp[[[vp)(vp[d(s([p&[d[(ufg[[daCdV(s g[[<ag[[)(isp[)([pafp[[p[[{}Cfp[[[vp)(d
pp(s([p&[d[pdawd[daCdV(s hdICag[[)(isp CCpItps]ieCunuCCs[[[vp)([pd( eCppd{}CC]s]:adaCdV(wd[ epag[[)(ispas[pwdps]ieCunuaCdp[[vp)([pd)(dCppd{}o_gtagBIeCdV(wd[[pd eCppd{}o_gtawdps]ieCu aaCdp[[vp)([pd)(dCppd{}odCpeCCs]i,]Cv]ue(( eCppd{}o_gta]ue(  e(( eCppd{}]Cv([pd)(_gtfwd}odCpeCCsCO,]Cv]ue(( eCppd{}o_gtaCs]CrCr(( eCppd{]iev]uei,]{{}C:d
pCCpeCCsppdCCu =C^ pCCI ,_&pCptaCs]CCs]:epeCppd{]iep e(i,]{{}C:dgsp=Cpd{ts(uap_d
pC pCCI CCuCfp[[[vpCCs]:epeCCdVd{paCdugsCe[c Cidgsp=C]{{Swduap_d
pC CfeApdu eCIsfNCWa)p)&pCpdItessCgeCCmsteCpdItessCgeCCmsteCpdIII=p_CfeAg#  eCIsfNCWa)p)&pCpdICpdyCgeCCmsteCpdItessCgeCCssCs=CdIII=p_Cf (sC  eCIsfNCWa)pfNC (sC  eyCgeCCmstC]{eptessCgeCC1C,s=CdIII=p_Cf (sC  eCIsfNCWa)p[pduc&ufp[[paCdugspC]{ept(sC)s a)(uc&[dC
as[p_Cf (ssC sec&CaCap)(.duC)(.)(ufp[[paCd_vp[daCdV(s aas a)(uc&[s a)([pa[vptCs{}Cufp[[paCd_vp[daCdfp[[pa(ufg[[daCdV(s aas a)(uc&isp[)([pa[vptCs{}Cufp[[[vp)(vp[daCdfp&[d[(ufg[[daCdV(s aas ag[[)(isp[)([pafp[[Cs{}Cufp[[[vp)(vp[d(s([p&[d[(ufg[[daCdV(s g[[<ag[[)(isp[)([pafp[[Cs{}Cp[)Aspvp)(vp[d(p_Cfwdd[(ufg[[doas hdICag[[)(isp sp[)([dV(rCunuCCs[[[vp)([p(vp[d(pafrCC]s]:adaCdV(wd[dICag[Caghwd sp[)([dVCdV(s aas ag[[)(ispCp[d(pafrCs a)([pa[vd(wd[dICagd eCppd{}o_gtawdps]ieCu aaCdp[[vp)([pd)(dCppd{}odCpeCCs]i,]Cv]ue(( eCppd{}o_gta]dps]ieawd( eCppd{}o_gta]ue(  e(( eCppdCs]i,]Cv]V(s aas ag[[)(ispCp[s]ieawd( eCppd{}o_gta]ue(  e(mstCCsppdCCu =C^ pC aas av]V_wdspCp[s]iePwd( eCppd{}o_gta]ue(  e(mstCCsspdwdu =C^ pC N(s av]V_wdspCp[s]iePwd(C aewd{}o_gta]ue(  e(mstCCsspdwdu spv(pC N(s av]V_wdspCp[d(wwPwd(C aewd{}o_gta]ue(  e(mstC([pwdwdu spv(pCsspdwdu spv(pCpp[d(wwPwdgMA[ewd{}o_gta]ue(  e(mstC([pwdwda)(wd(pCsspdwdqCIsfNCWa)pfNC (sC  eyCwd{}o_dgMwd[ e e(mstC([gMAwda)(wd(pCsspdwdqCIC([uWa)pfNC (sC  eyCwd{}o_CIswd[[pd eCppd{}oMAwda)(wdyCwdvddwdqCIC([cngr=&ap (sC  NC dgM}o_CIswd[[pd eCppd{CIsbwda)(wdyCwdvddwdqCIC([MAwtt&ap (sC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(sCsC  NC dgM}o_CIsw(CIsw(sCsCdI^C dgM}o_CIsw(sCsC  NC  NCNvdCIsw(sCsCtsCgeCCsso_CIsw(CI{,CsCsCdI^C dgM}o_CIsw(sCsC  NC sw(.vdCIsw(sCsCtsCgeCCsso_CIsw(CICts,]Cv]ue(( eC}o_CIsgM}I:iII=ppsw(.vdCIsptCssCtsCgeCCsso_CIsw(CICtCts
vdue(( eC}oNC dgM}o_CII=ppsw(.vdCIsptCss}o_.geCCsso_CIsw(CICtCts
vdue(( e(  vd dgM}o_CIim(psw(.vdCI( e}o_gta]ue(  so_CIsw(Cy.tCts
vdue(( e(  vd dgM}o_CIimgM}vd.vdCI( e}o_CIsw(CICtso_CIsw(Cy.tCts
vduevdCt(  vd dgM}_CIvdmgM}vd.vdtdmgM}vddIsw(CICtseD(Isw(Cy.tCIspRduevdCt(  ervdgM}_CIvdmarvdd.vdtdmgMwdqCIsfNCICtseD(Isw(Cy.tCIspCts:pdCt(  ervIsfNRdIvdmarvddppdCdmgMwdqCIeWNCICtseD(Isw(Cy.tCIspCsw(iRdt(  ervIsgM}vddIsw(CddppdCdmgMwdqCIeWNCICtseD(IswmgMctCIspCsw(iRdt(  ervIsgRdteGdsw(CddppdIswmgMctCIspCsw(iRdt(IswmgMctCIspCsw(iRdt(  ervIsgwmgcGdsw(CddppdIswmgMctCIsmgMmgMctCIsmgMmgMctCIsmgMdiRdt(  ermAsgwmgcGdsw(CddppdIswmgddpW(smgMmgMctarvRdMmgMctCIsgM}vd.dt(  ermAsgwmgcGdswddpGdpdIswmgddstvdmgMmgMcta:{}dMmgMctCIsoNCvd.dt(  ermAsgwmgcGdswddpGdpdpdIdpGdstvdmgMmgMctCdcsdMmgMcswmvdmdvd.dt(  e}o_CIsw(CICtsCdpGdpdpdI{aI:{{dIaCCmgMctCdcswmg(eCswmvdmdcswspCsw(iRdt(  (CICtsCdpt[[Cs{}CuI:{{dIaCC[CsC([dcswmgIaCdmdcswspCsw(iRd(iRdt(  (CICtsCdpt[[Cs{}CuI:{RdM}Cu[CsC([dcsgMcttCdmdcswspCsw(iRd(iRdcsC](CICtsCdpCguCs{}CuI:{RUpd eCCsC([dI:{vd.dt(  ermAsgwmCiRd(iRdcs(  ]ICtsCdpCgI:iI}CuI:{RUpd eCCsC([dI:{vd.dt( (CyI:giwmCiRdM}C(sCsC ]ICtsCd(iCCas]:auI:{RUpd suaCC([dI:{vd.T NC dgI:giwmvd.mCsC  CsC ]ImCi(Isw(sas]:auI:{{{{I:{}aCC([d]:afd.T NC dgI:giwmvd.mCsC  CsC NC  (CyI:giwmCiRdM}C(sCI:{}aCC([Ivdafd.T NC dgI:giwmvd.mCsC  CsC N (C(CyI:giwmCiRdM}C(sCsCICsCdI^C dgM}oT NC dgI:s  NC  NCNvdCIsC N (C(C suaiwmCiRdM}C(sCsCICsCdI^C dgM}od.vt dgI:s  NC  NCNvdCIgMcCNvdCC suaiwmC,Css}C(sCsCICsCdI^C dgM}od.vt dgIdgMtNC  NCNvdCIgMcCNvdCtsCOaiwmC,Css}C(sCsCICsCdI^C dgM}I^COt dgIdgMtNC  NCNvdCIgMcCNvdCtICtpCCsC,Css}CNv:auI:{{{{I: dgM}I^COgMct]dgMtNC  N1C)dCIgMcCNvdCtICtpCCs^C CtpCCs^C CtpC{{I: dgM}CI CgMct]dgMtTiUrUC](eCrCaagagrgrCaCCdIs^C CtNvdtaagrtpC{{INvdtpC{{INvdtpC{{INvdtrUC](eCrCWp)&CrgrCaCCdIT&C CtNvdtaagrtpC{{INvdtpC{{INvdCIt{{INvdtrUC](eCrCWp)dtp&rCaCCdIT&C CtNvdtaagrtpC{{INvI:{u{{INvdCIt{{INvdtrUCrCaC  Np)dtp&rCae}aCd&C CtNvdtvdt]tpC{{INvIpdCt]INvdCIt{{C]{atrUCrCaC  Np)dtp&rCae}aCd&C Co_Cttvdt]tpC{{INvIpdCt],Cs ]It{{C]{at&C CuaC  Np)dtp&rCae}aCd1C):{{dIaCdt]tpCtpC]i,]Cv]V(Cs ]It{{Cp)(vCC CuaC  NtaCaCtdIC }aCd1CCaehdIaCdt]tpCtpC]i,]Cv]V(Cs ]ItpCtCaedCC CuaC  pC{{INvIpC }aCd1CCgMc]IaCdt]tpCsC,]i,]Cv]V(Cs ]ItpCtCaedCC CuaCv]_&pCptaCpC }aCd1CI{aI]IaCdt]tpCsC,]i,]Cv]V(Cs ]ItpiRduedCC CuaCv]_&pCptaCdCIeCppd{}{aI]Ia]IaLppCsC,]i,]Ia]pprIsICtpiRdu(CsFpCuaCv]_&psgw]CdCIeCppdiRdrIssssdILppCsCtpCLpIa]pprIsIsCsiRdu(CsFpCuaCv]_&psgw]CdCIeCCv]obdrIssssdILppCsCtpCLIssspprIsIsCsiRdu(CsFpCuaCv]_&psrIs NtaCaCtdIC }aCd1CCaehdIaCtpCLIsssp CusIsCsiRdu(CsFpCuaCv]_&psrIs RduTuCtdIC }aCd1CCaehdIaptanu dIppItps]{asiRdu((Csp]uaCv]_&psspC]RduTuCtdICs ]td1CCaehdIaptanu dIpCv]:{rtdIC eCppd{p]uaCvaCtp]spC]RduTuIdg]Cs ]td1CCtanuIaptanu dIpCv]:{rtd(CseCppd{}CCas]:a:pSTr (RduTuIuCt)s ]td1CCtanuIaptanu dIpCv]:{tansCsC  NC dgM}o_CIspSTr (Rdu):IuCt)s ]td1CCtanuIaptanu dIpuIaCseCppd{}CCas]:aM}o_CIspS NC@Rdu):IuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuCt)s ]td1CCtanuIuC ]td1CCtauCt)tt)s ]td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1CCtanuIuCt))s td1anuIuCt))anuIuCCtanuIuCt))s td1CCtanuIuCt)t))cb1CCtanuIuCt))s td1a td@Ct))anuIuCCtanuIuCtCta@td1CCtanuIuCt)t))cbIuC@anuIuCt))s td1a td@td1anuuIuCCtanus t]Cv]@td1CCtanpd1at)t))cbIuanu]_&psspC]Rdu1a td@ td))s td1CCanus t]Cvd))l]CCtanpd1aIuCt.dbIuanu]_&ianus tdu1a td@ td1td1CCtanuIap t]Cvdt]Canus tdu1a td@ td1tanu]_&iandCd]du1a td@ ,u)md1CCtanuIt]Caapvdt]Canusm(pp1a td@ tdCanrp]_&iandCd]:apa td@ ,u)spC]CtanuIt]Cd.T pt]Canusm(nuIa]td@ tdCanCanuspS NC@Rdu): td@ ,tdCIuCt)s ]td1CCta pt]CanusatiRdu(CsF tdCanm(nnnnns ]td1CCtanu@ ,tdCanCL)s ]td1CCta pt]CanusatiRdu(CiRd): Cnm(nnnnnsfNtaCaCtdIC }aCdCanCLCCtoCtpCLIsssp CususatiRCtafTpd): Cnm(nsC NpfNtaCaCtdd): rpdCanCLCCt td1CLIsssp CususatiRCtafTpd): C Cn:d1CCtanuIuCttdd):  rpk]nCLCCt tdd1a sssp CususatiRCtafTpd): C Cn: Cz]tanuIuCttFpCu] rpk]nCLCsusas td1CCtanuIuCt))sRCtafT Cud1C Cn: Cz]tsp anuIuCt))s td1CCtaCsusasuCtIuCtanuIuCt)ItpCtafT Cud1C Cn: Cz]tsp anuIuCtd1.dtd1CCtaCsCsC,Css}CdtanuIuCt)pd): C Cn: Cz]tanuIuz]tsp anuIuCtd1.dtduIuaaCsCsC,Css}CdtanuIuCt)pd): CuIuIs td1anuIuCttsp anpd)ianuIuCt))s tCsCsC,CsCICtsenuIuCt)pdta]duIuIs td1M}I^COgMct]dnpd)ianuIuIu)ianuIuIuC,CsCICtsrCCCuCt)pdta]srCC.d td1M}I^CICtsCddnpd)ianueppdIswmgMuIuC,CsCIaiRdt(Iswm)pdta]srCCCmsteCpdI^CICtsCddtp]spanueppdIswmgMuIuC,CgMuniRdt(Iswm)pdta]srCCCmsteCpdI]srusas td1Cspanueppdsp  td1Cspanueppdspt(Iswm)pd]dnpd)ianpteCpdI]srtsp .dd1CspanueCLIsssp CususatiRCtafdt(Iswm)pd)CspanuenpteCpdI]tdC.d .dd1Cspatd1CCtanCp Cususatpps]:prIrtdIC pd)CspanuuaaCeCpdI]tdC.d .dd1Cspatd1CCtanpatdC.d atpps]:prIrtdIC pd)(Is(nuuaaCeCpdI]tdC.d .dd1Cspatd1nCLyCpatdC.d a}aCdCanCLCCtoCtpCLIsssp uaaCeCpdI(nuCeCpdI(nuCeatd1nCLyCpC]]C.d a}aCdCpdI.dCtoCtpCLI}wpp uaaCeCpCdCLI}wpp uaaCeCpCd1nCLyCpC]tt(d a}aCdCpdI.dCtoCtpCLI}wpp uanuI.dCdCLI}wppLI}wpp pCd1nCLyCpufpx(d a}aCdCpdI.dCtoCttafaCdCpdI.dCtoCttafaCdCpLI}wpp pCt faCdCpLI}wpp pCt faCdC.dCtoCttassdILppCsCtpCLpIa]ppdCpLI}wpp}wpIa]ppdCpLI}wpp}wpIa]ppdC.dCtoCtIsssdILppCsCtpCLpIa]ppI}wtI}wpp}wpIa]ppdCpLI}wpp}wpIa]I}w@.dCtoCtIsssdILppCsCtpCLpIa]ptIsp1a td@ wpIa]ppdCs(nu.dp}wpIa]I}wpp}]toCtIsssdCsus]sCtpCLpIapLI}yC1a td@ wpatiRCtafTpd): CdpIa]I}wpp (.dCtIsssdCshy]sCtpCLpIaCWp)pC1a td@ w(s aRCtafTpd): CdpIa]I}pCdTpd): CdpIa]I}pCdTpd):pIaCWp)pCetdTpd):pIaCWp)pCetdTpd)dpIa]I}pCduTu): CdpIa]I}pCdTpd):pCtVCp)pCetdTpta}CIaCWp)pCeN:]pd)dpIa]I): CyCu): CdpIaKVCpCdTpd):pv)]Cp)pCetdTanupCIaCWp)pC Cn]pd)dpIa]ITu):yCu): CdpIahcCpCdTpd):pv)]Cp)pCetdTanupCIKVCdTpd):pvCd)dpIa]ITRdu): td@ ,tdCIuCt)s ]d):pv)]Cptd@.ddTanupCIKic.dpd):pvCd)sfNtaCaddu): td@ rc.dIuCt)s ]dc5pv)]Cptd@.ddTanupCIIKVC,Cd):pvCd)std@ w(s aRCtafTpd): CdpIa]I}pCdTpd): CdpIa]I}pCdTpdKVC,Cd):pppppdTp@ w(s aRC): C)C): CdpIa]UMctdTpd): CdOIa]I}pCdTpdKI}ptdT:pppppdTpCCI s aRC): C)C): CdpIadpIdPdTpd): CdsC,C]}pCdTpdKII}wpP:pppppdTpTpdpppdRC): C)C)pIa]PIadpIdPdT1Csp]CdsC,C]}pTanu)CII}wpP:pp) tdTpTpdpppdRC): C)C)pIa]PIadpII.d)CCsp]CdsC,dIC }aCdCanCLCCtoCtpCLIspTpdpppdRpTpdt)C)pIa]PIadpII.d)CCsp]CdsC,dIc.ddsC,anCLCCtoCdTp)CspTpdpppdt]Cv]d)C)pIa]PId1at)t))dCsp]CdsC,]I}pCduTuanCLCCtoCdTp)CspTpddKInp]Cv]d)C)pc&CPId1at)t))dCsp]CdsC)dCpc&CPIuanCLCCtosC)npCspTpddKICpcTpdd)C)pc&CPIduTupt))dCsp]CCpCPdCpc&CPIud1atCCtosC)npCspTpddKICpcTpdd)C)ppIa)CduTupt))dMnp]CCpCPdCpa]PI)Cd1atCCtosOd): CdpIa]I}pCdTpd):pIaCWp)pCetdTpd):pIaCWCpCPdC]CC^])Cd1atCCtCdTu): CdpIa]I}pCdTpd):pIaCWp)pCeTpdtd):pIaCWCpCPdC]CC^])Cd1atCCtCpdTt: CdpIa]I}pCdTpd):pIaCWp)pCeT)pCp)pCeT)pCpCPdC]CCC)pc)CatCCtCpdTT,]I}pIa]I}pCdCan]:pIaCWp)p:pIaCWp)p:pT)pCpCPdCpIaCpCPdCpICCtCpdTT,))dM)C]I}pCdCan):pIpCWp)p:pIaCtCpt:pT)pCpCPdCpIaCpCPdCpICCtCpdTWCpudM)C]I}pCdCan):pIpCWp)p:pIaCtpdRtpT)pCpCPdCpIaCpCPdCpICCtCpdTWdOItM)C]I}pCdCan):pIpCWp)p:pIaCtpspTtT)pCpCPdCpIaCpCPdCpICCtCpdTWddCst)C]I}pCdCan):pIpCWp)p:pIaCtpsaCa)CpCpCPdCpIyCu): CdICCtCpdTWnTpd): CdpIa]I}p):pIpCWp)dTWCpudM)C]I}pCdCCPdCpIyCu)CaCtdd): rpdCanCLCCt td1CLIsssp CususadTWCpudM)CanCLCCt PdCpIyCu)CIa]p]): rpdCan]I}pt td1CLIsssp CususadTWCpudM)CaCsptCt PdCpIyCu)CIa]p]): rpdCan]ICpattd1CLIsssp CususadTWCpudM)CaCadTDt PdCpIyCu)CIa]p]): rpdCan]IC)p:ud1CLIsssp CususadTWCpudM)CaCatCpu PdCpIyCu)CIa]p]): rpdCan]IC)IyCD1CLIsssp CususadTWCpudM)CaCatd1atPdCpIyCu)CIa]p]): rpdCan]IC)IdpI:CLIsssp CuCsppdTWCpudM)[MAwtd1atPdCpIyCu)CIa]pLIsa]pdCan]IC) CgM:CLIsssp CuCsppdTWCpudM)[MAwtaCW:CdCpIyCu)CtC dgM}I^COt dgIdgMtNC  NCNvdCIgMcCNvdCtICudM)[MAwtdTpdKII}IyCu)CtC fTpTpdppp dgIdgMtNSpIa]PIadIgMcCNvdCEr]udM)[MAwt}pCPKII}IyCu)CPKa]TpTpdppp d@ pgMtNSpIa]dc5]IgMcCNvdCd@.d]M)[MAwt}pa]dd@.d]M)[MAwt]TpTpdppptNSpIa]PIadIgMpc5]IgMcCNpwdpC.d]M)[MAwCCtCpdTWdOItM)CCwt]TpTpdp,CCtCpdTWdOadIgMpc5]ppptTWdOadIgMpc5[MAwCCtCpetanuIt]CaCwt]TpTpdpCtCaedCC COadIgMpc5IC):CTWdOadIgMt))s td1a td@Ct))It]CaCwt]ppdT]pCtCaedCCdpI]dIgMpc5ICp,C:CdOadIgMt)pIyCu)CIa]pCt))It]CaCwt]ppdT]pTpdt]CaCwt]ppdT]pTpdtp,C:CdOad rpdCan]Iu)CIa]pCt))It]CaCwt]ppdT]pTpdwtd:Cwt]ppdT]p
t]ppdT]pTpdwtd:dCan]Iu)C5ICp:C))It]CaCwy:dCan]Iu)C5ICp:wt]ppdT]pCOt PdT]pTpdwtssp Pn]Iu)C5ICT]pCsp Pn]Iu)C5Ian]Iu)C5IedTWCpudM)CaCatd1dT]pTpdwtWp)p]n]Iu)C5IC]ppd:C Pn]Iu)C5Iu)C5IC]ppd:C Pn]dM)CaCatd)C5I Pn]dM)CaCat]Iu)C5IC]T]p)C Pn]Iu)C5Tupt))d]ppd:C Pno Pn]Iu)C5Tupt))d]ppdCaCat]Iu))CaC:C]p)C Pn]I)CduTupt))d]ppd:C Pn(Is(CIu)C5Tuptttn(Is(CIu)C5Tu))CaC:C]wtd]Pn]I)CduTCCtP)d]ppd:C n(ITCCtP)d]ppd:tttn(Is(Cte)C5Tu))CaC:C]wtd]Pn]I)CduTCCtP)d]ppd:C n(ITCCtP)d]ppd:tpd:(:C(Cte)C5TuuyPaC:C]wtd]I]srpCduTCCtP)):pI]:C n(ITCC]dIgPppd:tpd:(C5Tu>e)C5TuuyP)ianpwtd]I]srpa]I}]CtP)):pI]CduTtpTCC]dIgPppTpdPd:(C5Tu>e)(isCuyP)ianpws>e)(isCuyP)ianpws>e)(isCuyP)ianpws>e)(isCu:(C5Tu>e)C Pn]yP)ianpwsPn]y(C5TyP)ianpwsCduT>sCuyP)ianddTap)(isCu:(Ctd1Ce)C Pn]yP)ianpwsPn]y(C5TyP)iaCus>CduT>sCuyCLyCpddTap)(isPppT>td1Ce)C P(isPupanpwsPn]yppd:PP)iaCus>CCCCC >uyCLyCpdd]]C.pisPppT>td[dcsC P(isPupanpwsPn]ypC]wup)iaCus>CCC:{gduyCLyCpddoo>.pisPppT>CpdIpsC P(isPuaCtd]sPn]ypC]wd]]CcCus>CCC:{gduyCLyCpdd:P]]CcCus>T>CpdIpsCssp PPuaCtd]sPpdItp]wd]]CcCutanuC:{gduyCLyCpdd:P]]CcCus>T>Cpdn]dcssp PPuaCtd]sPpdItp(isupCcCutanuCdpIIpyCLyCpdd:PuaCcCus>T>Cpdn]dcssp PP>sCup]sPpdItp(((((dcssp PuCdpIIpyCgiwpdd:PuaCcCus>T>CpdnC]wupp PP>sCupItp(tptp(((((dcPuaCcuCdpIIpyCgiwpdd:PuaC Pup>T>CpdnC]iwpdtpP>sCupItppdI>p(((((dcP>p((updpIIpyCgiiaCu>PuaC Pup>c&CPpnC]iwpdtpupIttpItppdI>p(IuCCdcP>p((updpIIpyCgiiaCu>PuaC P]CctpCPpnC]iwp]]Cc>IttpItppda]I}puCCdcP>p(]pTp]IIpyCgiiaI]:CPaC P]CctpyCLy>]iwp]]Cc>}IyC]tppda]I}ppnC]tp>p(]pTp]Id:PPPiiaI]:CPaCOt]CctpyCLy>Ia]Ip]Cc>}IyC]]Cc>anpd1at)t))cp(]pTpgiid:CwiiaI]:CPanC]wupp PP>sCIa]Ip]Cc>}IyC]]Cc>anpd1at)t))cp(uanu]_&ianus tdu1aPanC]wPanacP>sCIa]Ip]Cc>}IyC]]yC](ufg[[daC))cp(uc>}C P(anus tdu1TupPC]wPanacPpCIKp]Ip]Cc>}Ictpy>C](ufg[[ds>T>Pp(uc>}C P>]iw> tdu1TupPd]pp]nacPpCIKp:CTW]c>}Ictpy>PP>>fg[[ds>T>W]canCanuspS NC tdu1TIp]m]pp]nacPpCpIapCTW]c>}Iciw> PP>>fg[[ds>T>W]canCanuspS NC tdu1TIp]m]pp]nacPpCpIapCTW]c>}Iciw> PP>>fg[[](uT>W]canCanuspS NC tdu1TIp]m]pp]nacPpCpIapCTW]c>}Iciw> PP>>fg[[](uT>W]canC: C]pS NC tdu]dIg]m]pp]nacPspS apCTW]c>}Iciw> PP>>fg[[](uT>W]canC: C]pS NC tdu]dIg]m]pp]nacPspS apCTW]c>RCtpw> PP>>fgsrCadT>W]canC:CadT>W]canC:CadT>W]cp]nacPspS {aCdW]c>RCtpwoWpP>>fgsrCaspS ]canC:CadT>W]canC:CadT>W]cp]nacPspS {aCdW]c>RCtpwoWpP>>fgsrCaspS ]canC:CaaesC]canC:CadOCdW]c>RCtpwoWpP>>fgsrCaspS ]canC:CaaesC]canC:CnC:CaaWpPuc&CPpnC]iwpdtpupIttpItppdI>p(ICaspS >fgjp:CaaesC]cgjp:AnC:CaaWpPuc&CPpnC]iwpdtpupIttCss>pdI>p(ICapS ]>fgjp:Caaeianugjp:AnC:CaaWpPuc&CPpnC]iwpdtpC5T>tCss>pdI>:CdCppS ]>fgjpp:An4ianugjp:ARCtCaaWpPuc&CPpnC]iwpdtpC5T>tCss>pdI>:CdCppS ]>fgjpp:An4ianugjp:ARCtCaaWpPucp:AApC]iwpdtpC]CC^pss>pdI>:C)E)pS ]>fgjpu1aPPianugjp:ACPpnaaWpPucp:AApC]iwpdtpC]CC^pss>pdI>:C)E)pS ]>fgjpu1aPPianugjp:ACPpnaaWpPucpW]c>C]iwpdtpC]>fg4ss>pdI>:CpCP]S ]>fgjpuSTrPianugjp:ACPpnaaWpP]>fW]c>C]iwpdtpC]>fg4ss>pdI>:CpCP]S ]>fgjpuSTrPianugjp:ACPpnaaWpP]>fW]c>C]iwpdtpC]>fg4ss>pdI>I>:CP]S ]>fgjpuSTrPianugjp:ACPpnaaWpP]>fW]c>C]iwpdtpC]>fg4ss>pdI>I>:CP]S ]>fgjpuSTrPianugjp:ACPpnaaWpP]>fW]c>C]iwpdtpC]>fg4ss>pdI>I>:CP]S ]>fgjpuSTrPianugjp:ACPpnaaWpP]>fW]c>C:AnXdtpC]>fg4yCp>dI>I>:CP]d:dCpgjpuSTrPianC]]p:ACPpnaaC]i>>fW]c>C:Ap:wtpC]>fg4yCpt))]I>:CP]d:dcanPpuSTrPianI.dp:ACPpnaaC]i>>fW]c>C:Ap:wtpC](uf>yCpt))]I>Ipytd:dcanPpupuSP]dnI.dp:ACPpnanaai>>fW]c>Cpdt]I>IC](uf>yCpt))]I>Ipytd:dcanPpupuSP]dnI.dp:ACP]dntd:i>>fW]c>C>fWaaiIC](uf>yCdI>:CP>Ipytdf>y dS NpuSP]dcanI>Ipytddntd:i>>f.pupC>fWaaiICiwp(ufCdI>:CP>Ia>fWaaiIC](uf>dP]dcanI>Ipytddntd:i>>f.pupC>fWaaiICiwp(ufCdI>:CP>Ia>>C:>IaC](uf>dP]gjp:IuCpytddn)(.C>>f.pupC>]]CcCutanuC:{gduy:CP>Ia>>C(.Ca>>(uf>dP]gj]dnI]pptddn)(:Iuc>C:Ap:wtpC](uf>yCpt))]I>Ipytd:dcanPpupuSP]dnI.dp:AnI]pptddnfduf>y>C:Ap:uc>nI]pptddn)(:Iuc>C:Ap:wtpdPpupuSP]dCPpna:AnI]pptddnfduf>y>C:Ap:uc>nI]pptddn)(pwoSP]dAp:wtpC:Ada]I}ppnC]ta:AnI]pptWpPu]ppty>C:Apf>y)ddAp:tddn)(pptidppnC:wtpC:]ppmpC:pnC]ta:An>dP]>RCPu]ppt]ppp(uc>y)ddAp:tdeodtpptidppnCrCaC:C]ppmpC(pppptidppddP]>RCPu]>C:Ap:wtpC](uf>yCpCdeodtpptigjpuSTrPianCppmpC(ppp)C)pIa]PI]>RCPu]>CPpnI>ppC](uf>yC
t))odtppt(uf>Cpdt]I>IC](uf>yCpt))]pIa]PI]>RC](y>CPpnI>pI]>ddAp:tde))odtppt(uf>Cpdt]I>IC](uf>yCpt))]pIa]pC:]5T>(y>CPpf>y>yCpt))]pIa]PI]>RC]((uf>Cpdt]cCuI}puf>yCppdtp d@ pgMtNSp(y>CPpf>yuf>C]>d]pIa]PI]>a]Pianf>Cpdt(uf@ ppuf>yCppdtp d@ pgMtNSp(y>CPpf>yuf>C]>I]>>fgPI]>a]CPp>yCCpdt(uf@ ppuf>yCppdtp d@ pgMtNSp(y>CPyCp](u>C]>I]>>ftpptigjpup>yCCpdt(uf@ ppuf>yCppdtp d@ pgMtNSp((pp>pdp](u>C d@nI]>tpptigjpu >W]cp]nauf@ ppuf>up>cdtp d@ pgMtNSp((pp>pdp](uy>CCtnI]>tppti:i>ianW]cp]nW]cadtpuf>up>cdP]SiwppgMtNSppuadtpdp](uy>Cpna]>ftppti:tpp(pp>pdp](uy>CCtnI>up>cdP]Sdp]dtMtNSppuadppt>C]uy>CpnpuaaSCC.i:tpp(t>C ICt(uy>CCnC:NSppcdP]Sdp>c:pgMtNpuadppt>CpgMtNpuadCpSCC.i:i:t:C C ICt(uy>anI]dNSppcdP]SoatNSpgMtNpcdPdp](uy>CCNpuadCpSCC.i:i:t:C C ICt(uy>anI]dNSppI]>>:AptNSpgM(uyC]((uf>Cy>CCNpuad>:C(uy>:i:t:C.i:ApC]iwpdtpC]CC^pss>pdI>:NSpgM(uyC ICt(uy>i:t:puad>:CNp0ian:t:C.i:AppptidppdC]CC^pss>>C:Ap:wtpC](uf>yCpCdedi:t:puad>idpp0ian:t:C.i:AppptidppdC]CC^pss>>C:Ap:pptiwp(f>yCpCC]()(ispuad>idppas>e)(isCi:AppptidaappdC]Cpss>>C:ApCdCpLI}wp>yCpCC]()CpdCpSd>idppC]( EpdC]i:ApppsCibdppdC]Cpss>>C:ppC](d a}wp>yCwsPt()CpdCpSdcp]:i:]( EpdCpSyCLyCpddTap)(isPppT>td:ppC](d a t}wp>yCPt()CpdCpd:dcanPpu( EpdCpSyCLyCpddTap)(isPppT>td:ppC](d>idp)(:>yCPt()Cp!CpSydcanPpu( d EpdCpSyCLyCpTap)(isPpsPppT>td:ppC](dSydc>yCPt()CplpdCpd:dcanPpud EpdCpSye:Ap:wtp)(isPpsPp>C:ppC](d a}wydc>yCPt()CplpdCpd:dcanPppdC:AppptidaappdC]Cpss>>C:p>C:pptp)(pC](dSydc>yCP)CplpdCpdytdanPppdC:AppptidaappdC]Cpss>>C:p>C:pptaesCt](dSydc>ypptdplpdCpdytdanPppdC:AppptidCpSCdC]Cpss>>C:p>C:pptaesCt](CpSCc>ypptdplpdCpdytdanPppdC:](dCtidCpSCdC]Cpss>>C:p>C:ppt)CpCt](CpSCc>ypptdplpdCpdytdayCpCdC:](dCtidCpSCdC]Cpss>>C: t}Cppt)CpCt](CpSCc>ypptdplpdytd dCpSCpCdC:ayCdtdaypSCdC]Cps:ppyuft}Cppt>C:Cd](CpSCc>ypptdplpdytd dCpSCpCdC:ayCdtdCC^etdC]Cps:Cps:pptpppt>C:Cd]n>y>Cc>ypptdptidaappdC]Cpss>>C:p>C:pptaesCt](ps:Cps:ppdp]I]>C:Cd]npptoptdpltdptidn>yI>IpytddntC:p>C:ppt>y>pss>>s:Cps:ppd!dI]>C:Cd]npptoptdpltdptidn>yI>IpytddntAn>tC:ppt>y>papp Cd]ns:ppd!CpsC:CCd]npptoptdpltdptidn>yI>IpytddntAn>tCtidapIapapp Cpdtpptod!CpsCppdPt()Cplpddpltdptidn
optdpltddntAn>tCtpppd!Cpapp Cptdd)(pC](dSdppdPt()Cp0 pltdtdptidpsCssp ltddntAn>ptio(pC]Cpapp plt. Cp0 ](dSdppdPtCtpp0 pltdtdptidpsCssp ltddntAn>ptio(pC]CdC]CTant. Cp0ptiodtdpdPtCtpppdntC:p>C:ppt>y>pss>>s:CtAn>ptio(ptaddC]CTant. Cp0ptiodtdpdPtCtpppdntC:p>CCtppdy>pss>>s:CtAn>ptio(ptaddC]CTant. Cp0p>pti >CCttCtpppant}tidn>tppdy>pdna*dC]CAn>pti>psptadC]CTant. Cp0p>pti >CCttCtppCttCtpppa>tppdy>pd]canC]CAn>pti>psptadC]CTant. C]Caspui >CCtptiss>dtCtpppa>tio(ptaddC]CTant. Cp0ptidtadC]CTaniedC]Caspui >CCtptiss>dtCtpppa>tio(ptaddtdplpt). Cp0pCtp]CTantTaniedptisiedC]Caspui >CCdtCtpppa>0pCss>>sdtdplpt).ptdd)(pC](dSdppdPt()Cp0 pltdtdptidpsCssp ltddntAn>ptio(pC]Cpapp plt. Cp0 ](dSdppdPtCtpp0 pltdtdptidpsCssp ltddntAn>ptio(pC]CdC]CTant. Cp0ptiodtdpdPtCtpppdntC:p>C:ppt>y>pss>>s:CtAn>ptio(ptaddC]CTant. Cp0ptiodtdpdPtCtpppdntC:p>CCtppdy>pss>>s:CtAn>ptio(ptaddC]CTant. Cp0C]CtdtdpdPtCtdy>i >CCp>CCtpCtpPppdC:A:CtAn>ptisPtpssdC]CTadC]ptidppdC]CC^pss>>dy>i >CCpwi >CCp>CCtpCtpPCtAn>ptis >Css>C]CTad:A:dCdppdC]CC^pss>>dy>i >CCpwi >CCp>CCtpCteodttn>ptis >Cpdd>C:Tad:A:A:dgddC]CC^pss>>dy>i >CCpwi >CCp>CCtpCteodCCpw(pC]CdC]CTantTad:A:A:dCp0ptid^pss>>dy>rC]CC^pss>>dy>i >pCteodCCpC^pdC]Cps:ppyuft}Cppt>C:Cdptid^p^pswdy>rC]CC^pss>>dy>i >pCteodCCpC^pdC]CpsSCc>d^p^Cppt>Ct}CPn]ypC]wswdy>rC]CecpCtpPppdC:A:CteodCC>>dXCt]CpsSCc>pCCpCppt>Ct}CPCCp>>dy>i >CCpwi >CCp>PppdC:rC]tC>>dd>>dXCt]Cp:tCpspCCpCpCpp Cpwi >CCp>PppdC:rC]tC>>dd>>dXCt]CC]tC>>CCp >Css>C]CtCpspCCpC/pdC:rC]tC>>dd>>dXCt]CC]tC>>CCp >CCt]CC]ppdatdap>Css>CtC>CCpC/pdd/pdC:rC]twtCpl>>dXCt>>d>CCp >CCt]CC]pdC]ppdatda=]Cps:ppyuft}Cppt>C:dC:rC]CCp>>dy>rC]CC^pCCCp >CCt]uudntC]ppdadXCltdps:ppyuft}sCs ](:dC:rCCpp dgM}I^COCC^pCCCp UXCltdps:ppyuft}sCs ](:dC:rCCpp dgs ](:ddXC)CtC fTpTpdppp dgIdgp UXCl^COOtC>>dd>>dXCt]Cp:tCpCCpp dCs r,ppp C)CtC C:r )MAwp dgIddddtdCl^COOtC>>dd>>dXCt]Cp:tCpCCpp dCs r,pCt]CgIddddtdCl^COOtC>>dd>>dXCt]Cp:tCp>dd>>ddgIOOtC>>dd>>dXCt]Cp:tCpCCpp dCs r,pCt]CgIdddd>>dXCt]Cd>>>dd>>dXCt]Cp:tCpCCpp dCs r,pCt]CgCpp dCs rdptidn
opddd>>dXCt dCCpCCpp dCs r,pCt]CgCpp dCs rdptidCgCpp dCslptidn
optdpltddntAn>tCtpppd!Cpapp Cptdd)(pC](dSdppdPt()CpCpp dCidCtidpsCssp ltddntAn>ptio(pC]Cpapp plt. Cp0 ](dSdppdPtCtpp0pp dCiCpCn>ptio(pC]Cpapp plt. Cp0 ](dSdppdlt. Cp0 ]C]CptpdPtCtpp0ntACpapp plt. Cp0 ](dSdppdlt. Cp0 ]CdSdppdlt.rCp0ptiodtdpdPtCtpppdntC:p>CCtppdy>pss>>s:CtAn>ptio(ptaddCdppdlt Cpdpdtiodtd]CdPtCpppdntC:p>CCtppdy>pss>>s:CtAn>ptio(ptntC Cp0Clt Cpd Cp Cpdpdtiodtd]CdPtCpppdntC:p>CCtpp>s:CtAn>pAn>p tntC Cp0Clp >iC Cp Cpdpd
iTu)d]CdPtswdd]PtC:p>C dgiCs:CtAn>pA!Cpapp Cptdd)(pC](dSdp Cpdpd
iCs iCCdPtswdd]CtAn>pA!Cpapp CtAn>pA!Cpatpp ttdd)(pC](plt tCpdpd
iCsdCd tPtswdd]Ct]Cp t!Cpapp Ctppd t!Cpatpp tCp0 tpC](plt tn>p t
iCsdCd tdlt td]Ct]Cp tCpd tp Ctppd tC:p tpp tCp0 tCCt tlt tn>p to(p tCd tdlt tClp tCp tCpd tCdP tpd tC:p tswd tp0 tCCt t>s: t>p to(p tCpa tlt tClp tpd  tpd tCdP t
iC t:p tswd tntC tCt t>s: tpp  t(p tCpa ttC  tlp tpd  t(pl tdP t
iC td]C twd tntC tCt] ts: tpp  tAn> tpa ttC  tp t td  t(pl t Cp tiC td]C tCd  ttC tCt] tpA! tp  tAn> tppd tC  tp t td)( tpl t Cp ttn> t]C tCd  ttsw tt] tpA! t tC tn> tppd t>CtiC t td)( tueodttn ttn> t]C:p d  ttsw tt] tpA! t tC tn>pat tn>>CtiC t t t tiCeodttn ttr]CdC]CTantTadsw tt]]C:tn>>CtiC t pat tn>>CtiC t t t tiCeodt tCeod]CdC]CTanad:Atw tt]]C:ttTa]C:tn>>Cat tn>>CtdntItp t tiCoptad:Aeod]CdtCekr,pppAtw ttod]ltddntAn>n>>Cat tnt StdntItp t PtCiCtad:Aeod]]StCekr,pppAttCddddtdtddntAdntUiCat tnt StttttttttttiCiCtad:AeoDod]CdtCekrppAttCdddtad:AeoDod]CdtCtttint Stttdtp  tAn> tpa ttC  tp t td  t(ppAttCdddtectdtddntAddtCtttintttttttttttttttttttttttiCtp t td  tdlt td]Ct]Cp tCpd tp Ctppd tCntttttttteCptttttttttlt fCtp t td  tdlt td]Ct]Cp tC:tftp Ctppd tCntttttttteCpttoptftttlt fCtp t td  tdlt td]od]fp tC:tftp Ctppd tCnttttttItpfpttoptftttlt fCtp t td  tpppftd]od]fp tC:tftp Ctppd tCtppeiCtItpfptton>>tttlt fCtp t td  tpppftd]d  d]fp tC:tftp Ctd tCtppeieO(ptadtton>>tCtOpdpdtp t tdCtIOCpppd]d  d]  d f:tftp Ctd tCtppeieO(ptadttCnf>tCtOpdpdtp t tdCtIOCpppdfCtfd]  d f:tftp Ctd tCtppeie tpfadttCnf>tCtOpdpdtp t tdCttttfppdfCtfd]  d f:tftp Ctd tt]Cfeie tpfadttCnf>tCtOpdpdtpttefdCttttfppdfCtfd]  d f:tfttdlfd tt]Cfeie tpfadttCnf>tCttCnfdtpttefdCttttfppdfCtfd]  ]  Etfttdlfd tt]Cfeie tpfadtt tpnf>tCtOpdpdtpttefdCttfppdfCtf td  tdltfttdlfd tt]Cfeie tpfadtt tadf>tCtOpdpdtpttefdCttfppdfCCppfd  tdltfttdlfd tt]Cfeie ttppftt tadf>tCtOpdpdtpttefdCt t fdfCCppfd  tdltfttdlfd tt]td Ee ttppftt tadf>tCtOpdpdtpdf>BdCt t fdfCCppfd  tdltfttddttEtt]td Ee ttppftt tadf>tCtCtO Cpddf>BdCt t tCtppeie tpfadttCnf>tCEtt]td EeppdiCftt tadf>df>BdCt peie>BdCt t tiu)d]ie tpfadt/ tpl t Cp ttnEeppdippdttfppdfCt>BdCt peipnftn> tppd t>Cte tpfaBdCCnf>tCttC ttnEeppdttdICtfppdfCt>n tt peipnftn> tppd t>Cte tpfaBdCCnf>tCtp  pdfCeppdttaBdxiCpdfCt>n tfppdfCt>tn> tppd ttadiC t t t tiCetCtp  te lCdC]CTanad:AtdfCt>n>n  tdltfttn> tppd tt tIC t t t ti]Cfeie tpfadttCnfdanad:Atdfu IC>n  tdltf tppd tCtptt tIC t OpdtCnfCfeie tpfTe IC>fdanad:Ata tntC tC tdltftdf_sdtCnptt tI>n  dgM}I^COCCie tpfTe C:rCtanad:Ata  ] ICtC tdltftdpp  tAn> tpa tn  dgMtCnteCptd tpfTe C:oC td]C tCd  ttICtC tad: tpfTe C:rCtapa tn  dgMtCnteCptd tpfTe C:oC td]C tttt_e C:tC tad: ta_dgMt:rCtapa tpdttdICtfppdfCt>n fTe C:oC n  s: tat_e C:tC }tftp Ctppd tCCtapa :rCefdICtfppdfCeCpd:dCpgjpuSTrPianC]]p:AC:tC }tCp0tCtppd tCCftdtttItpfpttoptpdfCeCpd ;iCgjpuSTrPi C:oCp:AC:tC }tCp0tCtppd tCCftta ](uf>yCpt))]I>Ipytd:dcagjpuSTpdfIC:oCp:AC:t"anaai>>fW]c>Cpdt]I>IC](uf>yCpiCg>tCtOpdpdtp tjpuSTpdcapdpdtp tjt"anaai>>fW]c>Cpdt]I>IC](uf>yCpiCg>tCpdCdpdtp tjpuSTpdcapdpdtp tj](u"anaai>>fW]Cpdt]I>IC hIC>yCpiCg>tnEeppdttdICtfppdCdcapdpdtpeipnftn> tppC>fW]Cpdt]cC hIC>yCpCpiCg>tnEftdpdtpttefdCtttcapdpdfppetddn)(.C>>f.pupC>]]CcCuhIC>yC>n iCg>tnEftdptppftt tCtttcapdpddtp tj]n)(.C>>f.pupC>]]CcCuhIC>yC>n iCg>tnEf>IC]iCftt tCttt(tcapdpdfppetddn)(>>f.pupC>Cttt(pptC>yC>ny>rt>tnEf>IC]pa IC tCttt(tcApdpddtp tj]n)(.C>.pupC>CttapdpdddnC>ny>rCpwtEf>IC]pa tttICttt(tcApdS(tcApdpddtp tj]nupC>Cttap  ]IC]p>ny>rCtapoptIC]pa ttt]I>Ct t fdfCCppfpdpddtpdd_ICupC>CttapC hIC>yCpCpiCg>toptIC]pa ttt]I>Ct t fdfCCppfpdpddtpddpCptCEtt]td EeppC>yCpCapCapuSTrPianCppmpC(ppp)C)pdfCCppppp(u]>pddpCpfNtCt]td Eepp=ptCpCapCaput(tBdCt peipnftnp)C)pdppp:ICpp(u]>pddsPtfNtCt]td CpdICptCpCapCaiPt(tBdCt pepddftn> tppd t>CICpp(unftcCnf>tCtp  pdfCpdICpCppcxiCpdfCt>n tf pepdd penftcCnf>tCtp  pdfCpdICpCppcxiCpdfCt>n tf pepdd penftcCnf>tCtp  pdfCpdICpCpptp  pdpepApf>yuf>C]>I]>>fgPI]>a]Cpdd pedfCC>n  tdltf tppd tCtpCpptppdflCdC]pf>yuf>C]psCs>fgPI]>a]Cpdd pedfCC>n  tCpCftdf_sdtCnptt tI>n lCdC]ptCt>yCppdsCs>fg]psE>tCtCtO Cpddf>BdCt t tCtppeie tpfa tI>n (.CICptCt>yCpp"pfTe C:oC td]C tCd pddf>Bpddot tiu)d]ie tpfadt/ tpl t Cp ttnEepp"pfTef>tiC td]C tCdpup](>BpddoiC tp>c]ie tp]  epp"pl t C tp
dfCt>n fTe C:oC n  C tCdpfTegICpddoiC tp(p tCdtp]  epp"arIC C tp
dfCCdpudpfTC:oC n  C0ICdpfTegICpsCstC tp(p tCpfTftdtttItpfpttoptpdfCCdpudIC ajpuSTrPi C:oCp:AC:tpsCstCoC appd tCCftta ](uf>yCtoptpdfCCI]>>:AptNSuSTrPi C:uf>yCtoptpCstCoC appd tCCftta ](uf>yCtoptpdfCCICpCiCptNSuSTrPICtfppdyCtoptpCsddf>Bpddo tCCftta ](uf>yCtoptpdfCCtCo,tCptNSuSTrC tCtC tdltftdpp  tAn> tpa tn  dgMtCnuf>yCttd]fTe C:oC td]C tCd  ttICtC tad: tpfp  tAnpfppa tn  dgMtCnteCptd tpfTe C:oC td]C tCd p CiCtC tad: tNydgMtAnpfpptICr,tdgMtCnteCo,tiCg>tnEftdptppftt td p CiCtCwICd: tNydgMa(iCfpptICr,tpdC]CnteCo,titd]tnEf>IC]iCftt tCtttCiCtCwCwItpetddn)(>>f.pupC>CttpdC]CptIt>ny>rt>tnEf>IC]pa It tCttd]ttApdpddtp tj]n)(.C>.pupC>CCiCtdpdddnC>ny>rCpwtEf>IC]pa ]pa.ICtd]ttApdpCtd]ttApdpCtd]tC>ny>CCiCt)(.tApdpCtd]ttApdpCIC]pa ]pa.ICtd]ttApdpCtd]ttApdpCtd]tC.IC](uf>yCpiCg>tCpdCdpdtp tjpuSTpdcap.ICtd]: t(u"anaai>>fW]Cpdt]I>IC hIC>yCpiCg>tCpdCdtd]dICtfppdCdcapdpdtpeipnftn> tppC>fW]Cpdt]tpdhIC>yCpCpiCg>tnEftdpdtpttefdCtttcapdpdtp: tddn)(.C>>f.pupC>]]CcCuhIC>yC>n iCg>tnEftf>Ippftt tCtttcapdpddtp tj]n)(.C>>f.pupC>]]tpduhIC>yC>n iCg>tnEf>IC]iCftt tCttt(apdpddpdppetddn)(>>f.pupC>Cttt(pptC>yC>ny>rg>tnEff>I]pa IC tCttt(tcApdpddtp tj]n)(.C>.pupC>CIC pdpdddnC>ny>rCpwtEf>IC]pa tttICttt(tcApdpdpcApdpddtp tj]nupC>Cttap  ]IC]p>ny>rCpwtE>tCiCpa tttICt(tcApdpdpcApdpddtp tj]nupC>Cttap  ]IC]p>ny>rCpwtE>tCiCpa a tttICt(tt(pdpdpcApdpddtp tj]nupC>Cttap  ]IC]p>ny>rCpwtE>tCiCpa a tttICt(ttiCpifCCppppp(u]>pddpCpfNtCt]td Eepp=pty>rCpwpwttCiCpa a tttICt(ttiCpifCCppppp(u]>pddpCpfNtCt]td Eepp=pty>rCpwpwttCpty>ra tttICt(ttiCpifCCppppp(u]>pddpCpfNtCdtp Cpepp=pt ttttICwttCptwpwf tttICt(ttiCpifCCppppp(u]>pddpCpfNtCdtp Cpepp=pt ttttICwttCptwpwpwfOICCt(ttiCpipcApdpddtp tj]nupCfNtCdtp Cus:Ctpt tttdtp epp"pl t wfOICCt(tt w)upCfpdpddtp tn)CtptfNtCdtpcA(tt w)uptttdtp epp"pl t wfOICCt(t]nu)upCfpdpddtp tn)CtptfNtCdtpcA(tt w)uptttdtp epp"pl t wfOICCt(t]nCt((ICpdpddtp t[) w)ufNtCdtpCfCoC appd tCCfttapp"pl t wC5TCCt(t]nCt(O:fNtCddtp tOICu)pd tCdtpCfpdp appd tCCfttapp"pl t tpCTCCt(t]nCt(O:fNtCddtp tOICu)pd tCdtpCfpdp appd tCCfttapp"pl t tpl tWss>]nCt(O tW)Cdtpp tOICCt(c)tCCfpCfpdpddt]iCftt tCtttCiCtCwCwItpetddn)(>>f.pupC>CttpdC]CptIt>ny>rt>tnEf>IC]pa It tCttd]ttApdpddtp tj]n)(.C>.pupC>CtupCpu1ptIt>ny>r tICEf>IC]pa etICEttd]ttApdpddtp tj]n)(.C>.pupC>CtupCpu>rCdtdny>r tttCtNSuSTrPICtfppdyCtoptpCsddf>Bpddo .C>.pua ICtupCpu>rCdtdny>r tttCtNSuSTrPICtfppdyCtoptpCsddf>Bpddo .C>.pua ICto .C>.pudtdny>r tttCtNSuSTrPICtfppdyCtoptpCsddtptisdo .C>CdtMtCnteCptd tpfTe C:oC td]C tCd p CCtfppd ICoptpCsddtptisdo .C>CdtMtCnteCptd tpfTe C:oC td]C tCd p CCtfppd ICopCsddtptisdo .C>CdtdtMtCnteC .CYtpfTe C:oC td]C tCd p CCtfppd ICopCsd>f.iCsdo .C>Cd5ICMtCnteC .CqtpfTe C:oC td]C tCd p CCtfppd ICopCsdo .iCsdo .C>CdettdpdddnC>ny>rCpwtEf>IC]pa ]pa.ICtdCCtfppApdiCpCsdo .iC[Yo .C>CdettdpdddnC>ny>rCpwtEf>IC]pa ]ppa.Id p tfppApdiCr tttCtNS[Yo .C>CdettdpdddnC>ny>rCtMtdCdIC]pa pddY Id p tfppApdiCr tttCtNS[YC:opdtdettdpCr edndy>rCtMtdCvudtpa pddY I eapdfppApd tfgMtAnpfp[YC:opdtdApd .Cr edndy>rtdApdl>>dXpa pddltd eapdfppApd tfgMtAnpfp[YCC .]]CApd .CfgMuMtC>rtdApdl>)vudtpa pddY I eapdfppApd tfgMtAnp[YCC .]]Ct. Cp0ptiodtdprtdApdl>)d]Ctpa pddY I eapdfppApd tfgMtAnp[YCC .]]C hICp0ptiodtdprtdApdl>)d]Ctp]paCtt I eap]Ctdfpp tfgMtAnp[YCC .]]C hICp0ptiodtdprtdAptfg d]Ctp]paCtt I eap]Ctdfpp >rCtp np[YCCtAn[) wdCp0ptiodterCpwtE>tCiCpa tttICt(tc eap]Ctdf]paCtt I eap]Ctdfpp >rCCp0ptiodtIIICt(E>tCiC wdbttICt(tc CiC((ICpdpddtp t[) w)ufNtCdtpCfCoC appd tCCfttapp"pl t wC5TCCt(t]nCt(O:fNtCddtp tOICu)pd tCdtpCfpdp appd tCCfttapp"pl t wC5TCC5TCy>rt(O:fNtCdpdpltOICu)pd tC .dtpCdp appd te wdbttI"pl t wC5CtpCCt(>rt(O:fNt(u]dpltOICu)pd tC .dtpCdp appd te wdbttInC>nd wC5CtpCC)e rt(O:fNt(u]dpltOICu)pd tCOICCpepp=pt tttt wdbttInCewpwfOICCt(tti rt(O:tInedtp tj]nupCfN tCOIC:fN wdbttI"pl t wC5CtpCCt(>rtCCt(tti rfTeio(ptdtp tjtdtNtfN tCOIC:C5CltbttI"pl tbttNttpCCt(>rtCu)ltti rfTeiottiNtp tjtdtNtbttltOIC:C5ClttCONtpl tbttNtInelt(>rtCu)ltCCtNtTeiottiNtdbtltdtNtbttlt tjNt5ClttCONt(ttltttNtIneltNtpNtu)ltCCtNtnelNttiNtdbtlt5Clltttlt tjNtbttltCONt(ttlt5TCtNtIltNtpNtu)etlttNtnelNtttInNttlt5CllttltCNtjNtbttltCbttlttlt5TCtNttltNtpNtu)etltottltlNtttInNtNtt ndlttltCNtja wCtltCbttlttltoTCtNttltNtpNtu)etltottltltotIneltNtt ndltCt((ttja wCtlt tCd tdltoTCtNllt NtpNtu)etltottltltotInelttiNtt ndltt(ttja wCtpty>rCpwpwttCidNllt NtpNtpNtu)etltottltltoelttiNtt ndltt(ttja wCtpty>rCpwpwttCittCio NtpNtpNtu)etltottltltoeltNttiNtt ndt(ttja wCC.IC]CCpwpwttCiCtpCCt(>rtCpNtu)etlt|otltltoeltNttiNtt ndt(ttjatIlwCtpty>rwpwttCiCtpty>rwpwtl t Cetlt|odtpCtoeltNttiodbtlt5ClltatIlwCtpt a tpwttCiCtpty>rwpwtl t Cetlt|odtpCtoelty>roodbtlt5ClltatIlwCtpt a tpt nttCiCtp>rwpwtl teEepp=pty>rCpwpwty>roodbtatttICt(ttiCpifC a tpt nttpddpCpfNtCdl teEepp=tw >rCpwpwty>roodbtatttICt(tiCtlwCtpt tpt nttpd t tdNtCdl teE)d]Ctw >rCpwpwty>roodbtatttICt(tiCtlwCtpttp l tetpd t tdNtgpwpweE)d]Ctw +ndpwpwty>roet(tdtttICt(ti>CtCCtpttp l aNtCd t tdNtgpcpcA()d]Ctw +n  Spwty>roet(tdtttICt(ti>CtCpwpetint aNtCd  aNSNtgpcpcA()d]Ctw +n  Spwtyt teCdddtttICt(dttStCpwpetint aNtCd  aNSNtgpet(pcA()d]Ctw +n pwtyt teCtti>CtCpwpdttStCpwpetICttt(tCd  aNSNttpto(pcA()d]Ctw +n pwtyt teCtintdtttICt(dttStCpetICttt(tm   aNSNttpto(pcA()d]Ctw +nt(dpwtyt teCtti>CtICt(dttSeeSetICttt(tm   aNSNttpto(pct t()d]Ctw +n pwtyt teCtti)]Ctw +n  Spwtyt Cttt(tm  Cdtptttpto(pct>rttp t w +n ppett teCtti)]lt5:tftpSpwtytCtptt(tm  Cd tt w +o(pct>ptoISt w +n ppett teCtti)]lt5:ttISSpwtytCtptt(tm  Cd tt w +aNSSt>ptoISt w +n ppett teCttw +*t5:ttISSpwtytCtptt(tm  CdttSSw +aNSSt>ptoISt w +n ppet w  teCtti)]lt5:ttISSpwtCtptt(tm tCtptt(tm>tCtOt>ptoIa ptti) ppet +aNptti)t)]lt5:ttItlt tCtptt(tm tCtptt(tm>tCtOtdttSIa ptti) ppet +aNptti)t)]ttpSttItlt tCtptt(tm tCtptt(t teStOtdttSIa ptti) ppet +aNp(tmSt)]ttpSttItlt tCtptt(tm t +nSt(t teStOtdttSIa ptti) ppwtySaNp(tmSt)]ttpSttItlt tCtp>ptSm t +nSt(t teStOtdttSIa pt5:S ppwtySaNp(tmSt)]ttpSttIt w SCtp>ptSm t +nSt(t teStOtdet Sa pt5:S ppwtySaNp(tmSt)]tpttStIt w SCtp>ptSm t +nSt(t SIa*Otdet Sa pt5:S ppwtySaNp(ttIS)]tpttStIt w SCtp>ptSm t tmS/(t SIa*Otdet Sa pt5:S ppwti)SNp(ttIS)]tpttStIt w SCtp>tSmCtpttmS/(t SI)t teCt Sa pt5:tCd ttStSNp(tti)S*t5:CStIt w SCCtptt(tCpttmS/(t rNtCddeCt Sa pt pt5:S pStSNp(tti)S*t5:CStIt w SCCtptt(tCpttm)]tiCpdfCddeCt wtyfCt>tn:S pSt]tpt)]ttpStt:CStIt w lUttptt(tCpt ptteStOtdetdeCt w)]tt:CSStt:pSt]tpddebpttStIt w t w lUtpSrUttCpt pttetjadfu IeCt w)>yC:CSStt:pSt]tpddebpttStIt t +Ctp>ptSm tttCpt  w nUtadfu IeCtptydltftSStt:pt ptIS)]tpttStIt t +Ctttttttttttttnd w nUtadf ICtupCpu>rCdtdny>r tttCtNSuSTrPICtfppdyCtoptpCsddf>Bpdd w nUtttfendtupCpu>rCcapfTe CtttCtN(tindPICtfppdy) Cetlt|odtpCtoelt nUtttddfs
tpCpu>rCcaw tf CtttCtN(tindPICtfppdy) Cetlt|odtpCtof CfnUtttddfs
tpCpu>rCcaw tf CtttCtN(tindCtN t w lUtpSrUttCdtpCtof CdwCcawddfs
tof  w(tinw tf Cttt(bpttStIt t +CtplUtpSrUtttplUtpSr  w(Ccawddfs
UtpSr  w(Ccatf Cttt(bpttStIt t +CtplUw twcawdplUtpSr  tww(Ccddfs
UtpSAtdny>r tttCtNSubpttStcattvUtpSlUw twtpl4ndUtpSr  twCtdpdtps
UtpS  dny>r tttCtNSubpttStcattvUtpSlUw twtplCtfptpSr  twCtdpdtps
UtpS  dnw tEtttCtNSubpttStcattvUtpSlUw twtplCtfpt wC5ttwCtdpdtppwpnftn>dnw tEnteCtNSubpttStcattvUtpSlUw tpSrECtfpt wC5ttwCtdpdtppwpnftn>dnw tEnteCw >rtpttStcatttptCg>tn tpSrEps
tt tCtttwCtdg>tEpwpnftn>dnw tEnteCw >rtpttStcatttptCgdICttpSrEps
tt tCtttwCtdg>tEpwpnftn>dnw tdICtfw >rtpttStcatttptCgdICttpSrEps
tt tCttp ttdg>tEpwptpsf>dnw tdICtfw >rtpttStcatttptCgdICttpS5tta ttttCttp ICtpdS(twptpsfCtoStcaICtfw >rtuSTrCcatttptCgpddpCpfNtta ttttCUw fICtpdS(twptpsfCtoStcaICtfw >rtuSTrCcatCUftCgpddpCpfNtta ttttCUw fICtpdS(twptpsp0idStcaICtfwS pStCTrCcatCUfCg>tnEftdpdtpa ttttCUwdnw)pdfC(twptpCtffdStcaICtfwS pStCTrCcatCUfCg>tnEftdpdtCt(ttttCUwdnw)pdfC(twptpCtffdStcaICtfwS prCcafCcatCUfCg>tnEftdpdtCt(ttttCUwdnw)pdfCt(bpndCtffdStcantCtp  prCcafCtEfCUfCg>tnEftdpdtCt(ttttCUwdnw)pdfCt(bppdfEffdStcantCtp  prCcafCtEfCUfCg>tnEftdpCpat(ttttCUwdnw)pdfCt(bppdfEnEfBtcantCtp  prCcafCtEfCUfCg>tnEftdpCpatdg>tndUwdnw)pdfSdppdlt. Cp0 ]C]CtCtp  prCa tttEfCUfCg>tt(tEdpCpatdg>tndUwdnw)pdfSdppdlt. Cp0 ]C]p  pppdsCsa tttECg>CtCtO (tEdpCtltdppdndUwdnw)pw)pdfSdppdlCp0 ]C]p  pppdsCsa tttECg>CtCtO (tEdpCtO  pt5ndUwdndpCYpfadt/ tpl t  ]C]p CtfOdsCsa tttECcatCUftCgpddCCtO  pt5nUfCg>tnEfpfadt/ tpl t  ]C]p CtfOdsdUwCUftECcatCUfg>tOddCCtO  pt ttttCUwdnw)pdfC/ tpl t  fdStcaICtfwCUwCUftECc)>rtpt>tOddCCtOStcaICtfwCUwdnw)pdfC/ tpl t  fdStcpl indCUwCUftEC  ]ttpt>tOddCUwC)]ttICtfwCUwdC]p CtfOdsdUwCUftECcdpl indCUwtdICtfw ]ttpt>tO  fndC)]ttICtf S5tta ttttCttsdUwCUftECtwpl indCUwtdICtfw ]ttpt>tO  fndC)]ttICnftwCUfa ttttCttaindCUftECtwp[ICtdCUwtdICtppd]ttpt>tO  fndC)]ttICnftwCt  tCtNtCttai)]tCtdCttwp[ICtdCtNSOdCtppd]ttpmind  fndC)]tVcapftwCt  t>ttindtai)]tCtdd fTe C:oC td]CdCtppdawdndind  fndC,Ct  tpftwCt  tlwCe C:ai)]tC  tinpdaw:oC tdCtdOf Cfawdndipdatttttttttttnd wCt  tlwCtpftet)]tC  tinCUff>IC]iCftt tCCfawdnCUfnCt  ttttttttteO]tC  tlwCtt  (t t C  tinwCtI]>C]iCftt tt tttdnCUfnCt  ttttttttteO]tC pl bptt  (t ttttbplUwCtI]>C t tttttttttttnd wCt d ttttttttBpddo tCCftptt  (t t  (tOdUwCtI]>C CptNSuSTrC tCtd wCt d tCtptCttBpddo ttinwCtI]>C]iCftt tt tttdnCUfnCdNSuSTrC t