# BiliBili tvOS 客户端 Demo

### 本项目没有任何授权的 Testflight 发放以及任何收费版本，请注意辨别和考虑安全性问题。

 **BiliBili tvOS 客户端 Demo 从未在任何平台上架和收费（包括AppStore与Testflight）**

 如果您在任何平台上看到有人以收费方式提供本项目的服务或应用，请注意这是**未经授权的**行为，并且与我们的原始意图不符。我们强烈谴责将本项目用于商业盈利的行为，由此引发的任何安全风险与此项目无关。


### 支持功能
- 二维码登录
- 云视听小电视投屏协议
- 直播与弹幕
- 推荐Feed
- 热门
- 排行榜
- 搜索
- 关注列表
- 历史播放
- 稍后再看
- 系统播放器播放视频
- 视频弹幕
- 热门评论
- 弹幕防挡
- 云视听投屏
- HDR播放
- 字幕
- 手机上传自定义 Top Shelf 图片
- 推荐与关注页可选沉浸式浏览
- TV 推荐独立页面
- 播放器信息面板发现 Tab
- 视频选集范围跳转
- UP 主空间按播放量排序

### 上游同步

本 fork 于 2026-10-11 同步至 [原项目 `078cfde`](https://github.com/yichengchen/ATV-Bilibili-demo/commit/078cfde)，保留自定义 Top Shelf 图片上传、App Group 和 fork 的构建配置。

2026-10-17 再次拉取上游确认，`upstream/main` 仍为 `078cfde`，当前 fork 已包含最新上游更新。

本次更新包括播放流畅度与海外网络高码率优化、沉浸式浏览及内容安全过滤、头像尺寸限制，以及 UIScene 生命周期适配。沉浸式浏览可在设置的“推荐”和“关注页面”中开启。

沉浸式播放最初由 @hugohua 在原项目 #195 中实现，后续由原项目在 #211–#216 中拆分、重构和修复。

### 本机模拟器构建

Xcode 16.4（Swift 6.1）使用仓库中的 `Package.resolved`，其中 Alamofire、swift-log、swift-protobuf 分别锁定为 5.10.2、1.6.4、1.31.1，以兼容本机工具链。

```bash
xcodebuild -project BilibiliLive.xcodeproj -scheme BilibiliLive \
  -configuration Debug -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
  -derivedDataPath /tmp/ATV-Bilibili-Simulator \
  -skipPackageUpdates -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO build
```

构建目录应放在项目外，避免构建脚本中的 SwiftFormat 扫描生成目录及第三方依赖。

2026-10-17 在 Apple TV 4K（第 3 代）/ tvOS 18.5 模拟器上完成 Debug 构建、安装和运行验证，直播列表、沉浸式推荐、预览及全屏播放均可操作。

模拟器的 H.264 兼容处理：
- 原始 H.264 MP4 在独立的最小 AVPlayer 程序中也出现绿色偏色和块状失真，同一文件在 macOS 原生解码正常；同一内容的 HEVC 流在 tvOS 模拟器中显示正常。故障位于本机 tvOS 模拟器的 H.264 解码/显示路径，绕过网络、DASH 转换及弹幕插件后仍可复现。
- 模拟器构建在存在 HEVC 流时仅将 HEVC 提供给播放器，避免自适应选流重新切回 H.264。CDN 测速和画质菜单采用相同策略，菜单保留原始流索引。真机保持原有编码选择。
- HEVC 流已实测两条不同视频的预览、全屏播放和切换，未再出现绿色偏色或块状失真。未提供 HEVC 时回退到原始视频流，不拦截播放、不显示编码兼容限制提示；这类资源在模拟器中仍可能失真。
- 用户已在 Apple TV 实机验证，未出现绿色偏色及块状失真，因此移除了模拟器的编码拦截和相关提示。实机保持原有编码选择。

### 自定义 Top Shelf 图片

本项目支持在 Apple TV 运行时从手机上传图片替换系统首页的 Top Shelf 展示图。

使用方式：
1. 在 Apple TV 上打开 App 的设置页。
2. 选择“手机上传 Top Shelf 图片”。
3. 确保手机和 Apple TV 在同一局域网内，然后用手机浏览器打开弹窗中的地址。
4. 上传一张横向高分辨率图片。系统会按 Top Shelf 展示区域自动适配。
5. 如需恢复内置默认展示，使用上传页中的“恢复默认图片”。

开发和签名要求：
- 主 App 和 `BilibiliTopShelfExtension` 都需要开启同一个 App Group：`group.com.zemise.tv.BilibiliLive`。
- 自定义图片保存在 App Group 容器的 `Library/Caches` 下。
- 上传时会为图片生成新的文件名，避免 tvOS 复用旧 Top Shelf 图片缓存。

 ![](imgs/1.jpg)
 ![](imgs/2.jpg)
 ![](imgs/3.png)



### Telegram Group
 - https://t.me/appletvbilibilidemo

### 未签名iPA文件

从 https://github.com/yichengchen/ATV-Bilibili-demo/releases/tag/nightly 获取基于最新代码构建的

### Links

- App Icon [【22娘×33娘】亲爱的UP主，你怎么还在咕咕咕？](https://www.bilibili.com/video/BV1AB4y1k7em)

- [thmatuza/MPEGDASHAVPlayerDemo](https://github.com/thmatuza/MPEGDASHAVPlayerDemo)

- [dreamCodeMan/B-webmask](https://github.com/dreamCodeMan/B-webmask)

- [分析Bilibili客户端的“哔哩必连”协议](https://xfangfang.github.io/028)

### 推荐页快速切换稳定性

2026-10-17 复现快速下翻闪退，异常为 `AVPlayerLayer was deallocated while key value observers were still registered`，观察路径是 `readyForDisplay`。移除了对 `AVPlayerViewController.isReadyForDisplay` 的 KVO 转发观察，改用主线程短时轮询，首帧就绪或停止播放时取消；销毁控制器前显式注销其余 KVO。该生命周期修复同时用于模拟器和实机。

闪退修复后复测：发送 130 次下翻输入（含快速连按及 350ms/1200ms 按键停留），日志记录 15 次 AVPlayer 装配，同一应用进程持续运行超过 4 分钟，未生成新的崩溃报告。移除编码兼容限制提示时保留了此项生命周期修复。

### 沉浸式推荐预览起播优化

2026-10-18：预览使用独立的媒体预热缓存，按下一条、上一条、下两条的顺序提前准备 AVURLAsset、播放清单及主视频分段索引；切换时复用已准备资源，缓存最多保留 4 条，超出邻近范围的预热取消。单个预览控制器退出不再清空浏览器管理的预热缓存，离开浏览器时统一清理。

切换防抖由 250ms 缩短为 150ms。当前视频首帧显示后才启动邻近预览预热，之后仅预热当前视频的全屏资源，减少与下一条预览争抢带宽。保留原有预览请求参数、画质策略及首帧就绪后展示画面的行为。

本机 tvOS 18.5 模拟器 Debug 构建通过，运行日志确认预览媒体缓存命中；本次 26 次起播样本从选中到首帧约 291–1225ms（包含防抖，不包含后续淡入动画），多数约 400–600ms；运行期间未发现新增崩溃报告。此为优化后样本而非同条件前后对比，实机及不同网络仍需验证；未缓存的视频和 CDN 缓冲仍可能显示加载转圈。

### 双向预览预缓冲

在清单和索引预热基础上，为紧邻的下一条和上一条视频创建静音、暂停的 AVPlayer，提前缓冲并 preroll，切换时将同一播放器交给 AVKit。双向预缓冲并行执行，最多两个后台播放器；下两条保留轻量清单与索引预热。预热匹配续播位置，接用后避免重复 seek；预热失败或超时回退到原有加载流程。准备完成的相邻视频跳过 150ms 防抖，未准备完成时继续防抖。加载指示器等待 200ms 后才显示，避免短暂等待闪一下转圈；200ms 内首帧就绪时采用 120ms 淡入，长等待仍保留加载提示。后台预滚等待设置为 4 秒，切走、超出邻近范围或离开页面时清理，预热不调用 play、不上报观看历史。

2026-10-18 初次验证曾记录预缓冲接用后显示首帧约 77–134ms，但随后用户发现向下切换后只显示静帧、没有播放。这些数字仅代表画面就绪，不作为实际起播速度结论。原因是 item 在接用前已 ready，而 status KVO 未投递初始值，导致漏掉自动播放；已补上初始状态处理及当前 item 身份校验。首帧验证同时要求播放器处于 playing，避免将静帧误判为起播。首次或未命中预缓冲的资源仍可能需要等待。 修复后重新验证：多条预缓冲接用后同时满足 playing 和画面就绪，样本约 77–106ms；未完全预热的样本耗时更长。末条视频连续两个 5 秒日志周期均保持 playing、stalls=0、keepUp=1，确认接用后实际播放。

### 本地实机打包

在项目根目录运行：

```bash
make package
```

依次执行签名 Release 归档和 `xcodebuild -exportArchive -allowProvisioningUpdates`，产物为：

- `build/BilibiliLive.xcarchive`
- `build/ExportOptions.plist`
- `build/export/BilibiliLive.ipa`

首次导出时从 `config/ExportOptions.plist` 复制配置；已有的 `build/ExportOptions.plist` 会保留。默认模板使用本项目团队的自动签名和 `debugging` 导出方式，安装设备须包含在相应描述文件中；需在 Xcode 登录有权限的开发者账号并具备可用签名身份。更换团队或导出方式时修改导出配置及项目签名设置。

打包前先执行依赖解析，使用锁文件版本并禁用 SwiftPM 共享仓库缓存；依赖解析成功后才备份、替换旧归档。可通过 `make resolve` 单独准备依赖。2026-10-18 修复默认构建目录中 Kingfisher 旧缓存缺失 8.7.0 提交的问题，依赖版本保持不变；旧缓存曾只包含到 8.5.0，直接跳过远端更新会导致 `reference is not a tree`。

可单独归档、重新导出或覆盖路径：

```bash
make archive
make export
make package EXPORT_PATH="build/export-custom" EXPORT_OPTIONS_PLIST="config/ExportOptions.plist"
make package-unsigned
```

`package-unsigned` 输出 `build/export/BilibiliLive-unsigned.ipa`，供自行重签。归档与导出严格顺序执行，即使用 `make -j package` 也不会并发；已有归档会改名为同目录的 `.previous.<时间>-<进程号>` 备份。构建缓存默认放在仓库外，避免 SwiftFormat 扫描第三方依赖。已有 SPM 缓存可通过 `SOURCE_PACKAGES_DIR` 指定，构建缓存可通过 `DERIVED_DATA_PATH` 指定。所有目标只负责构建、导出，不执行 Git 提交或推送。

首次进入沉浸式推荐时，拿到首个含可播放视频的批次便显示并起播，不再等待累计 12 条；保留内容过滤规则和最多扫描页数。首条跳过切换防抖，避免焦点事件重复取消首条加载；首帧播放前延后推测性分页，起播或首条失败后继续补齐列表，新补齐视频也会加入邻近预热。

主标签页创建时，在启用沉浸式推荐的前提下预取一次推荐原始首屏；30 秒内首次进入时复用该请求或结果，再按当前过滤设置处理。过期或预取失败则重新请求。此预取不创建隐藏页面、不下载视频；避免把推荐数据请求留到切入页面才开始。

### 确认进入短视频流的连续播放过渡

已有预览真正起播时，按确认键将同一预览控制器移入短视频流页面，继续显示画面和播放声音；后台按原有完整画质、字幕与弹幕流程准备新播放器。新播放器准备期间静音，待其实际 playing 且画面就绪后停止预览、切换画面并解除静音。新播放器开始时读取预览的最新进度，减少等待期间进度回退；匹配视频与分 P，避免把上一条的播放进度带到其他视频。

重挂预览时保留播放，退出或提前切换视频时清理过渡控制器；重复确认不再重复创建短视频流页面。预览尚未起播时沿用原有进入流程，网络卡顿和完整流本身加载失败仍需要等待或重试。

2026-10-18 模拟器 Debug 构建通过，两条视频的完整流分别在约 494ms、485ms 后实际起播，切换日志中预览/完整流进度分别为 2s/2s、1s/1s；过渡期间原预览继续播放。完整流准备时间仍存在，该过渡用于承接这段等待，不代表媒体请求已变成零耗时。

### 短视频流退出后保留进度和缓冲

从沉浸式推荐进入的短视频流退出时，将当前完整播放器在系统退出动画完成后放回推荐页，切换为无控件的内嵌展示，保留 AVPlayer、播放进度、暂停状态及已加载缓冲。再次按确认键直接将同一控制器恢复为全屏，不重新运行播放信息和弹幕加载。翻到其他视频、离开推荐页或刷新列表时按原有流程清理。画中画退出不采用这条回收路径。

返回内嵌后再次进入时，移除内嵌布局约束、恢复 UIKit 管理的根视图尺寸，并显式采用全屏呈现；返回完成时同步重置呈现标记。退出和内嵌结束时通过独立进度保存回调上报观看进度，保留可复用的详情菜单与插件状态。

首次进入的衔接进度使用小数秒和 600 timescale，避免向下取整导致语句重复。完整流就绪后先保持静音，在预览继续播放的同时追齐进度；两者时间差在 25ms 内才切换画面和声音。若完整流提前则等待预览追上，切换结束恢复预览的播放速率；取消或退出会清理同步计时器。日志 `[feed-entry] synchronized-handoff` 记录实际切换时的进度差。

2026-10-18 模拟器验证：三条视频切换时进度差约为 -24ms、-22ms、-17ms，静音追齐耗时约 250–262ms，期间预览继续播放；用户试听反馈“没有重复了”。退出后仍保留同一播放器和进度。
