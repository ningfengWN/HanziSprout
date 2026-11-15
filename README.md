# 字芽 · HanziSprout

给刚学完拼音、开始写日记的孩子做的 iPhone / iPad 查字工具。最低 iOS / iPadOS 16，无账号、无广告，无需 AI API Key。

## 使用

1. 输入词句，或点麦克风说“蝴蝶的蝶怎么写”。说完停止录音，再点“找字”。
2. App 优先提取引号里的目标字、“的某字怎么写”等表达；其他句子展示全部汉字供点选。同音字需要检查识别结果，用拼音键盘更正。
3. 点字进入全屏田字格，自动按笔顺书写。支持重播、暂停/继续、下一笔、底字开关、速度调整。自动演示中点“下一笔”可切换到逐笔查看，从第一笔开始；完整演示结束后也从第一笔重新开始。
4. 上方标注带声调的拼音，可修改多音字读音；支持系统中文朗读。最近 24 个字保存在本机，可清空。

## 在 Mac 上安装

1. `git clone https://github.com/ningfengWN/HanziSprout.git`
2. 用 Xcode 打开 **HanziSprout.xcodeproj**，选择 **HanziSprout** scheme。
3. 在 Signing & Capabilities 中选择自己的 Development Team；如 Bundle ID 冲突，将 `com.ningfeng.HanziSprout` 改为自己的标识。
4. 选择 iPhone / iPad 模拟器直接运行，或连接已启用开发者模式的真机运行。
5. 首次录音允许“麦克风”和“语音识别”。拒绝权限后仍可输入查字，可到系统设置修改权限。

免费 Apple ID 的真机签名需要定期续签。Simulator 构建产物不能直接安装到真机；本仓库不包含签名证书或可直接安装的 IPA。

## 实现与边界

- SwiftUI 原生界面、AVAudioEngine + Apple Speech 中文语音识别、WKWebView 本地笔顺渲染。
- Hanzi Writer 3.7.3 和 hanzi-writer-data 2.0.1 固定版本，构建时自动下载并校验固定 SHA-256 字库，随 App 捆绑 9,574 个字，无运行时字体或字形下载。首次构建需要访问 npm registry，之后可离线构建。
- 语音识别可能需要网络，并由 Apple 服务处理。录音仅在点击麦克风后启动；停止、查字、切换后台会结束录音。本 App 不保存录音、不上传到自建服务器，不接第三方 AI 服务。
- 词句提问解析采用本地规则，不是大模型。能提取“蝴蝶的蝶怎么写”、引号中的目标字等常见表达；其他输入让孩子点选目标字。暂不支持只说拼音就自动消歧。
- 拼音使用系统 Mandarin-to-Latin 转换，连续汉字按整词转换；包含标点或混合文字时退回单字。多音字仍可能读错，允许修改显示拼音。系统单字朗读不跟随手动拼音。
- 笔顺来源为开源字库，不承诺每个字都符合学校教材采用的笔顺版本。缺字时仅显示静态字和提示，不生成猜测笔顺。可按教材反馈逐字核对。
- iPhone / iPad 横竖屏自适应，尊重安全区域。旋转后会重新演示。

## 校验

```sh
sh scripts/prepare_data.sh
python3 scripts/check_data.py
node --check HanziSprout/Resources/writer.js
# macOS:
cat HanziSprout/Question.swift scripts/question_checks.swift > /tmp/question_checks.swift
swift /tmp/question_checks.swift
xcodebuild -project HanziSprout.xcodeproj -scheme HanziSprout -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions 在 macOS 上运行字库检查、解析检查、iPhone/iPad 通用模拟器构建。麦克风授权、中文语音识别和真机签名需要在设备上确认。

工程文件已提交，不依赖 XcodeGen；修改源文件列表后可运行 `python3 scripts/generate_project.py` 重建工程。

## 第三方许可

- [Hanzi Writer](https://github.com/chanind/hanzi-writer) — MIT，见 `HanziSprout/Resources/Licenses/HanziWriter-MIT.txt`。
- [Hanzi Writer Data](https://github.com/chanind/hanzi-writer-data)，来源 [Make Me a Hanzi](https://github.com/skishore/makemeahanzi) / 文鼎字形 — Arphic Public License，完整原始许可和署名随 App 捆绑在 `Resources/Licenses`。字形数据未修改。
