# 字芽 · HanziSprout

给刚学完拼音、开始写日记的孩子做的 iPhone / iPad 查字工具。最低 iOS / iPadOS 16，无账号、无广告，无需 AI API Key。

## 使用

1. 输入词句，或点麦克风说“蝴蝶的蝶怎么写”。看到“正在录音”后再说话；说完点“说好了”，等待整段录音识别完成，再点“找字”。中间停顿不会自动结束录音。
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

- SwiftUI 原生界面、AVAudioRecorder 手动结束录音 + Apple Speech 整段中文语音识别、WKWebView 本地笔顺渲染。
- Hanzi Writer 3.7.3 和 hanzi-writer-data 2.0.1 固定版本，构建时自动下载并校验固定 SHA-256 字库，随 App 捆绑 9,574 个字，无运行时字体或字形下载。首次构建需要访问 npm registry，之后可离线构建。
- 语音识别可能需要网络，并由 Apple 服务处理。录音仅在点击麦克风后启动；停止、查字、切换后台会结束录音。录音临时写入本机缓存文件，识别完成、失败、取消或进入后台后即删除；本 App 不保留录音历史、不上传到自建服务器，不接第三方 AI 服务。
- 词句提问解析采用本地规则，不是大模型。能提取“蝴蝶的蝶怎么写”、引号中的目标字等常见表达；其他输入让孩子点选目标字。暂不支持只说拼音就自动消歧。
- 拼音使用系统 Mandarin-to-Latin 转换，连续汉字按整词转换；包含标点或混合文字时退回单字。多音字仍可能读错，允许修改显示拼音。1.2 版拼音朗读按修改后的音节选择同音字。
- 笔顺来源为开源字库，不承诺每个字都符合学校教材采用的笔顺版本。缺字时仅显示静态字和提示，不生成猜测笔顺。可按教材反馈逐字核对。
- iPhone / iPad 横竖屏自适应，尊重安全区域。旋转后会重新演示。

## 校验

```sh
sh scripts/prepare_data.sh
python3 scripts/check_data.py
node --check HanziSprout/LearningAssets/writer.js
# macOS:
cat HanziSprout/Question.swift scripts/question_checks.swift > /tmp/question_checks.swift
swift /tmp/question_checks.swift
xcodebuild -project HanziSprout.xcodeproj -scheme HanziSprout -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions 在 macOS 上运行字库检查、解析检查、iPhone/iPad 通用模拟器构建，并检查实际产物的 Bundle ID、可执行文件和离线资源，分别在 iPhone、iPad 模拟器安装与启动。麦克风授权、中文语音识别和真机签名需要在设备上确认。

工程文件已提交，不依赖 XcodeGen；修改源文件列表后可运行 `python3 scripts/generate_project.py` 重建工程。

## 第三方许可

- [Hanzi Writer](https://github.com/chanind/hanzi-writer) — MIT，见 `HanziSprout/LearningAssets/Licenses/HanziWriter-MIT.txt`。
- [Hanzi Writer Data](https://github.com/chanind/hanzi-writer-data)，来源 [Make Me a Hanzi](https://github.com/skishore/makemeahanzi) / 文鼎字形 — Arphic Public License，完整原始许可和署名随 App 捆绑在 `LearningAssets/Licenses`。字形数据未修改。

## 更新后仍提示 Missing bundle ID

关闭 Xcode，拉取最新 main（或重新下载 ZIP），重新打开工程。在 Product 菜单选择 Clean Build Folder（Shift+Command+K），再运行。工程使用显式 `HanziSprout/Info.plist`，将 Bundle ID、可执行文件名和版本写入实际 App。资源目录使用 `LearningAssets`，避免 App 根目录出现保留的 `Resources` 目录，导致系统错误识别 Bundle 布局。

若清理后仍使用旧产物，退出 Xcode，在 Finder 的“前往文件夹”打开 `~/Library/Developer/Xcode/DerivedData`，只删除 `HanziSprout-` 开头的目录，重新打开工程运行。无需重置模拟器，也不需要修改 Apple ID。

## 录音交互

- 点一次开始，允许权限，出现“正在录音”和计时后说话；点“说好了”后才结束录音并识别。
- 录音期间不启动语音识别，因此识别服务的静音判断或提前返回不会结束麦克风采集。
- 权限弹窗造成的 inactive 状态不再取消录音准备；真正进入后台、来电或系统音频中断会结束录音并清理临时文件。
- 识别阶段有 30 秒等待上限（与录音时长无关），可主动取消；文字输入查字不受识别服务是否可用的影响。
- 麦克风授权、停顿后继续说、手动结束录音及识别准确率需要真机验收。模拟器可运行界面，但不替代设备音频测试。

## App 图标

1.1 版使用原创“字与小芽”图标，已接入 Assets.xcassets / AppIcon，iPhone 和 iPad 共用。

## 1.2 蜡笔纸张界面与拼音朗读

- 统一浅色纸张背景，所有正文、提示和输入文字使用明确的深色，避免手机深色模式下白字看不清。
- 首页改为彩色蜡笔卡片；笔顺页保持大字为主体，拼音放大到 iPhone 60 / iPad 80 点，并可点喇叭重听。进入大字页默认自动读拼音，可关闭。
- 按拼音的完整音节和声调，用普通话系统语音朗读同音单字；不把拼音当英文字母拼读。多音字修改为 háng / hang2 等后，朗读会使用修改后的音节。暂不提供声母、韵母拆分拼读。
- 内置 1,056 个带调音节的同音字索引，由 pypinyin 0.55.0 的单读音数据生成，MIT 许可见 LearningAssets/Licenses/Pypinyin-MIT.txt。常见多音字教学采用明确的同音单字，如 háng→杭、xíng→形。缺失音节会明确提示，不猜读音。
- 朗读效果仍受设备的中文语音资源影响，需要真机确认发音和音量。

## 1.3 芽芽英语（不接 AI 服务）

底部“写汉字 / 说英语”分开。英语页包含：

- **中英查句**：62 句、8 个生活场景，支持双向整句和明确别名匹配。片段输入只返回“相关例句”，不会冒充直接翻译。未知句子明确提示不在句库，不判断对错。
- **常见纠错示例**：12 个整句错误示例，展示中文意思、改正后的英文和原因。只有完整匹配例句才触发，不提供通用语法纠错。
- **朗读**：英文正常速度、慢速重听、中文意思朗读，使用系统语音。不需要 AI Key，不调用翻译或大模型 API；需要设备装有相应系统语音。
- **离线语音输入**：英语页按当前方向使用中文 / 英文识别，先检查设备 supportsOnDeviceRecognition，再设置 requiresOnDeviceRecognition；不支持或失败会提示改用输入或点选，不回退到云端。说完手动结束后，再点“查句”。准确率和离线模型支持需要真机确认。现有认字页的语音识别配置不变。
- **场景练习**：看中文试说英文、显示提示、听示范、手动录音回放、自行决定下一句。本地记录自己标记练过的句子；无自动发音评分。当前录音在切换句子、页面、进入后台时删除，不上传、不保存历史录音。

本版提供固定场景入门和系统离线翻译，不提供自由 AI 对话或通用纠错。设备缺少离线语音资源时，仍可输入、浏览句库及录音回听。

自动校验覆盖全部句子的双向查询、别名、标点大小写、未知输入、关键词建议与纠错范围，避免把未匹配英文宣称为正确。

### 句库之外的系统翻译

iOS / iPadOS 18 及以上，查句没有整句命中时，会显示“系统离线翻译”入口。按按钮后使用 Apple Translation.framework，系统可提示下载中英文语言包；准备完成后翻译输入文字，并提供译文朗读和慢速朗读。没有第三方翻译 API 或自建后端。翻译不等于语法检查。

语言包下载、取消、离线翻译和实际译文质量需要在支持的真机上验收；此能力不能靠模拟器编译通过来证明可用。旧系统保留句库与录音练习，失败时也可以回到句库。
