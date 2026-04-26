#import "YTLite.h"

// ─────────────────────────────────────────────
// MARK: - Extra headers
// ─────────────────────────────────────────────

@interface MLFormat (DL)
@property (nonatomic, readonly) NSURL *URL;
@property (nonatomic, readonly) NSString *mimeType;
@property (nonatomic, readonly) long long contentLength;
@end

@interface YTSingleVideoController (DL)
@property (nonatomic, readonly) NSArray *selectableAudioFormats;
@end

// ─────────────────────────────────────────────
// MARK: - Singleton download context
// ─────────────────────────────────────────────

@interface YTLDLContext : NSObject
+ (instancetype)shared;
@property (atomic, copy) NSString *videoID;
@property (atomic, copy) NSString *videoTitle;
@property (atomic, copy) NSArray  *videoFormats;
@property (atomic, copy) NSArray  *audioFormats;
@property (atomic, weak) UIViewController *sourceVC;
@end

@implementation YTLDLContext
+ (instancetype)shared {
    static YTLDLContext *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [self new]; });
    return s;
}
@end

// ─────────────────────────────────────────────
// MARK: - Safe URL extraction from MLFormat
// ─────────────────────────────────────────────

static NSURL *safeURLForFormat(id fmt) {
    if (!fmt) return nil;
    NSURL *url = nil;
    @try { id v = [fmt valueForKey:@"URL"]; if ([v isKindOfClass:[NSURL class]]) url = v; } @catch (...) {}
    if (url) return url;
    @try { id v = [fmt valueForKey:@"streamURL"]; if ([v isKindOfClass:[NSURL class]]) url = v; } @catch (...) {}
    return url;
}

static BOOL isAudioOnlyFormat(id fmt) {
    @try {
        NSString *mime = [fmt valueForKey:@"mimeType"];
        if ([mime hasPrefix:@"audio/"]) return YES;
        int res = [[fmt valueForKey:@"singleDimensionResolution"] intValue];
        return res == 0;
    } @catch (...) { return NO; }
}

static NSString *labelForFormat(id fmt) {
    @try {
        NSString *q = [fmt valueForKey:@"qualityLabel"];
        if (q.length > 0) return q;
    } @catch (...) {}
    return @"?";
}

// ─────────────────────────────────────────────
// MARK: - Download helpers
// ─────────────────────────────────────────────

static dispatch_queue_t dlQueue(void) {
    static dispatch_queue_t q;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ q = dispatch_queue_create("com.ytlite.dl", DISPATCH_QUEUE_SERIAL); });
    return q;
}

// Show a toast via YouTube's own toast system (main thread only)
static void showToast(NSString *msg) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIViewController *top = [%c(YTUIUtils) topViewControllerForPresenting];
            [[%c(YTToastResponderEvent) eventWithMessage:msg firstResponder:top] send];
        } @catch (...) {}
    });
}

// Actually download the file and save it
static void performDownload(NSURL *streamURL, NSString *filename, BOOL isAudio) {
    if (!streamURL) { showToast(LOC(@"DownloadError")); return; }

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.timeoutIntervalForRequest  = 60;
    cfg.timeoutIntervalForResource = 600;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg];

    showToast(LOC(@"DownloadStarted"));

    NSURLSessionDataTask *task = [session dataTaskWithURL:streamURL
                                       completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err || !data) {
            showToast(LOC(@"DownloadError"));
            return;
        }

        // Write to temp file
        NSString *tmpPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
        BOOL wrote = [data writeToFile:tmpPath atomically:YES];
        if (!wrote) { showToast(LOC(@"DownloadError")); return; }
        NSURL *tmpURL = [NSURL fileURLWithPath:tmpPath];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (isAudio) {
                // Audio → share sheet (Files / AirDrop / etc.)
                UIActivityViewController *share = [[UIActivityViewController alloc]
                    initWithActivityItems:@[tmpURL] applicationActivities:nil];
                UIViewController *top = [%c(YTUIUtils) topViewControllerForPresenting];
                if (top) [top presentViewController:share animated:YES completion:nil];
            } else {
                // Video → save to Photos library
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:tmpURL];
                } completionHandler:^(BOOL ok, NSError *e) {
                    showToast(ok ? LOC(@"DownloadSaved") : LOC(@"DownloadError"));
                    // Clean up temp file
                    [[NSFileManager defaultManager] removeItemAtPath:tmpPath error:nil];
                }];
            }
        });
    }];

    [task resume];
}

// ─────────────────────────────────────────────
// MARK: - Download sheet presenter
// ─────────────────────────────────────────────

static void showDownloadSheet(void) {
    YTLDLContext *ctx = [YTLDLContext shared];
    if (!ctx.videoID) { showToast(LOC(@"DownloadNoVideo")); return; }

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            YTDefaultSheetController *sheet =
                [%c(YTDefaultSheetController) sheetControllerWithParentResponder:nil];

            // ── Audio option ──
            NSArray *aFmts = ctx.audioFormats;
            id bestAudio = nil;
            long long bestBitrate = 0;
            for (id fmt in aFmts) {
                @try {
                    long long br = [[fmt valueForKey:@"bitrate"] longLongValue];
                    NSURL *u = safeURLForFormat(fmt);
                    if (u && br > bestBitrate) { bestBitrate = br; bestAudio = fmt; }
                } @catch (...) {}
            }
            // Fallback: pick audio-only from video formats list
            if (!bestAudio) {
                for (id fmt in ctx.videoFormats) {
                    if (isAudioOnlyFormat(fmt) && safeURLForFormat(fmt)) { bestAudio = fmt; break; }
                }
            }

            if (bestAudio) {
                NSURL *audioURL = safeURLForFormat(bestAudio);
                NSString *safeTitle = [ctx.videoTitle stringByReplacingOccurrencesOfString:@"/" withString:@"-"] ?: ctx.videoID;
                NSString *audioFilename = [NSString stringWithFormat:@"%@.m4a", safeTitle];

                [sheet addAction:[%c(YTActionSheetAction)
                    actionWithTitle:LOC(@"DownloadAudio")
                    iconImage:[UIImage systemImageNamed:@"music.note"]
                    style:0
                    handler:^{
                        dispatch_async(dlQueue(), ^{
                            performDownload(audioURL, audioFilename, YES);
                        });
                    }]];
            }

            // ── Video options (max 2 qualities to keep UI clean) ──
            NSMutableArray *videoOptions = [NSMutableArray array];
            for (id fmt in ctx.videoFormats) {
                if (isAudioOnlyFormat(fmt)) continue;
                NSURL *u = safeURLForFormat(fmt);
                if (!u) continue;
                [videoOptions addObject:fmt];
            }
            // Sort by resolution descending and show up to 3
            [videoOptions sortUsingComparator:^NSComparisonResult(id a, id b) {
                @try {
                    int ra = [[a valueForKey:@"singleDimensionResolution"] intValue];
                    int rb = [[b valueForKey:@"singleDimensionResolution"] intValue];
                    return rb - ra;
                } @catch (...) { return NSOrderedSame; }
            }];
            NSUInteger maxVid = MIN(videoOptions.count, 3u);
            for (NSUInteger i = 0; i < maxVid; i++) {
                id fmt = videoOptions[i];
                NSURL *vidURL = safeURLForFormat(fmt);
                NSString *label = labelForFormat(fmt);
                NSString *safeTitle = [ctx.videoTitle stringByReplacingOccurrencesOfString:@"/" withString:@"-"] ?: ctx.videoID;
                NSString *vidFilename = [NSString stringWithFormat:@"%@_%@.mp4", safeTitle, label];

                [sheet addAction:[%c(YTActionSheetAction)
                    actionWithTitle:[NSString stringWithFormat:@"%@ (%@)", LOC(@"DownloadVideo"), label]
                    iconImage:[UIImage systemImageNamed:@"film"]
                    style:0
                    handler:^{
                        dispatch_async(dlQueue(), ^{
                            performDownload(vidURL, vidFilename, NO);
                        });
                    }]];
            }

            if (videoOptions.count == 0 && !bestAudio) {
                showToast(LOC(@"DownloadNoFormats"));
                return;
            }

            UIViewController *top = [%c(YTUIUtils) topViewControllerForPresenting];
            if (top) [sheet presentFromViewController:top animated:YES completion:nil];

        } @catch (NSException *e) {
            showToast(LOC(@"DownloadError"));
        }
    });
}

// ─────────────────────────────────────────────
// MARK: - Capture active video context
// ─────────────────────────────────────────────

%hook YTPlayerViewController

- (void)loadWithPlayerTransition:(id)arg1 playbackConfig:(id)arg2 {
    %orig;

    if (!ytlBool(@"ytlDownloader")) return;

    // Delay 2s so formats are populated
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @try {
            YTLDLContext *ctx = [YTLDLContext shared];
            ctx.videoID    = self.contentVideoID;
            ctx.videoTitle = self.playerResponse.playerData.videoDetails.title;

            NSArray *vFmts = self.activeVideo.selectableVideoFormats;
            ctx.videoFormats = vFmts ?: @[];

            NSArray *aFmts = nil;
            if ([self.activeVideo respondsToSelector:@selector(selectableAudioFormats)])
                aFmts = self.activeVideo.selectableAudioFormats;
            if (!aFmts)
                @try { aFmts = [self.activeVideo valueForKey:@"selectableAudioFormats"]; } @catch (...) {}
            ctx.audioFormats = aFmts ?: @[];

        } @catch (...) {
            // Never crash YouTube
            YTLDLContext *ctx = [YTLDLContext shared];
            ctx.videoID = nil;
        }
    });
}

%end

// ─────────────────────────────────────────────
// MARK: - Add download button to player overlay
// Hooks into the long-press gesture already on the overlay view.
// We add our button next to existing action buttons.
// ─────────────────────────────────────────────

// ─────────────────────────────────────────────
// MARK: - Add download button to player overlay
// ─────────────────────────────────────────────

%hook YTMainAppVideoPlayerOverlayViewController
- (void)handleMoreButtonPressed:(id)arg1 {
    if (ytlBool(@"ytlDownloader")) {
        showDownloadSheet();
        return;
    }
    %orig;
}
%end

// ─────────────────────────────────────────────
// MARK: - Add Download item to the "..." sheet that appears on video cells
// We detect video-context sheets by checking our stored videoID.
// ─────────────────────────────────────────────

static BOOL g_addedDLAction = NO;

%hook YTDefaultSheetController

- (void)presentFromViewController:(UIViewController *)vc
                         animated:(BOOL)animated
                       completion:(void (^)(void))completion {
    g_addedDLAction = NO;

    YTLDLContext *ctx = [YTLDLContext shared];
    if (ytlBool(@"ytlDownloader") && ctx.videoID.length > 0 && !g_addedDLAction) {
        g_addedDLAction = YES;
        @try {
            [self addAction:[%c(YTActionSheetAction)
                actionWithTitle:LOC(@"DownloadVideo")
                iconImage:[UIImage systemImageNamed:@"arrow.down.circle.fill"]
                secondaryIconImage:nil
                accessibilityIdentifier:@"ytlite.download"
                handler:^{ showDownloadSheet(); }]];
        } @catch (...) {}
    }

    %orig;
}

%end
