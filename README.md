# BiliBili tvOS 客户端 Demo

### 本项目没有任何授权的 Testflight 发放以及任何收费版本，请注意辨别和考虑安全性问题。

**BiliBili tvOS 客户端 Demo 从未在任何平台上架和收费（包括 AppStore 与 Testflight）**

如果您在任何平台上看到有人以收费方式提供本项目的服务或应用，请注意这是**未经授权的**行为，并且与我们的原始意图不符。我们强烈谴责将本项目用于商业盈利的行为，由此引发的任何安全风险与此项目无关。

### 支持功能

- 二维码登录
- 云视听小电视投屏协议
- 直播与弹幕
- 推荐 Feed
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
- HDR 播放
- 字幕

### Fork 说明

本项目 fork 自 [yichengchen/ATV-Bilibili-demo](https://github.com/yichengchen/ATV-Bilibili-demo)，于 2026-10-31 同步至上游 `46904be`。保留上游功能，并增加：

- 手机上传自定义 Top Shelf 图片
- 沉浸式推荐的媒体预热、预缓冲和全屏连续播放衔接
- 本地签名及未签名 IPA 打包命令

沉浸式浏览源于上游实现；本 fork 的相关改动集中在播放稳定性和衔接体验。上游新增的长按快捷操作、清除已看完及多 CDN 并发加速也已同步。

![应用截图](imgs/1.jpg)
![应用截图](imgs/2.jpg)
![应用截图](imgs/3.png)

### Telegram Group

- [上游讨论群](https://t.me/appletvbilibilidemo)

### 未签名 iPA 文件

从[上游 Nightly Releases](https://github.com/yichengchen/ATV-Bilibili-demo/releases/tag/nightly)获取上游最新代码构建的版本；该版本不包含本 fork 的额外改动。

自行构建本 fork 可运行 `make package-unsigned`，签名打包运行 `make package`。签名前请配置本机团队、Bundle ID 和 App Group，详见[开发说明](docs/DEVELOPMENT.md)。

### 自定义 Top Shelf 图片

在设置中选择“手机上传 Top Shelf 图片”，用同一局域网内的手机浏览器打开提示地址，上传横向图片。上传页也可恢复默认展示。个人图片通过运行时上传，仓库使用公共默认图片。

### 开发与贡献

- [构建、签名和验证记录](docs/DEVELOPMENT.md)
- [隐私与推送说明](docs/PRIVACY.md)
- [上游 PR 候选清单](docs/UPSTREAM-PR-CANDIDATES.md)

### Links

- App Icon [【22娘×33娘】亲爱的 UP 主，你怎么还在咕咕咕？](https://www.bilibili.com/video/BV1AB4y1k7em)
- [thmatuza/MPEGDASHAVPlayerDemo](https://github.com/thmatuza/MPEGDASHAVPlayerDemo)
- [dreamCodeMan/B-webmask](https://github.com/dreamCodeMan/B-webmask)
- [分析 Bilibili 客户端的“哔哩必连”协议](https://xfangfang.github.io/028)
