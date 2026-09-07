# 拐弯 / TurnCue

只在需要时，告诉你下一步。

TurnCue 是一个 iPhone 路线草图原型。它不取代导航软件，而是把真实路线压缩成少量方向、地标和关键决策点，让人像看纸质地图一样先形成整体认识。

## 项目与公开页面

- 远端仓库：[xiaomao361/turncue](https://github.com/xiaomao361/turncue)。
- 当前工程：`0.4 (4)` 原型；尚未在项目页公布 App Store / TestFlight 下载渠道。
- 网站源码：[产品首页](docs/index.html)、[使用说明](docs/guide/index.html)、[隐私政策](docs/privacy/index.html)、[获取支持](docs/support/index.html)、[版本记录](docs/changelog/index.html)。
- [站点维护与发布说明](docs/PUBLIC_SITE.md)、[App Store 中文信息草稿](docs/app-store/METADATA_ZH_HANS.md)、[发布前检查](docs/app-store/RELEASE_CHECKLIST.md)。
- 支持邮箱：<zhouwei@linux.com>。
- App 首页的“关于与帮助”提供离线说明、隐私与支持页面，以及定位设置和邮件反馈；维护与验收见 [App 帮助页说明](docs/APP_HELP.md)。

公开站点计划地址为 `https://xiaomao361.github.io/turncue/`；页面已准备，部署与公开可访问性尚未验证。

网站静态检查：`python3 scripts/check_site.py`。本地预览服务：`python3 -m http.server 8080 --directory docs`。

## 当前原型

第一阶段先验证表达与状态流，并加入一个可上手机试走的 MapKit 技术原型。应用可以：

- 获取使用期间的位置权限。
- 输入时显示地点建议，搜索后按距离排列，先展示最近地点及地址，其余结果折叠。
- 搜索与路线生成显示等待状态，可取消；修改搜索词会丢弃旧请求结果。
- 支持扩大搜索范围或直接在地图上选点。
- 点地点卡片只选中目的地；确认区可选择步行、驾车、骑行或按距离推荐，再点“查看路线”。
- 把 MapKit 路线压缩为最多 3–7 个方向、地标和关键决策点。
- 搜索确认后先展示真实地图底图与完整路线线条，只标记少量关键节点。
- 每个节点都有可记忆的名称；轻点地图或路线索引可查看如何抵达以及抵达后的动作。
- 跟随时底部只有一个主按钮；暂停、退回、分享图和 Apple 地图入口位于右上角菜单。进入最后一段后，仍需手动确认到达目的地。
- 查看其他节点不会改变跟随进度；主按钮会先返回当前节点。全部节点按需展开。
- 在地图下方用精简节点说明方向、地标和决策，并显示估算距离与时间。
- 可生成一张包含地图、路线和节点说明的图片，通过系统面板保存或分享。
- 随时把起终点及交通方式交给 Apple 地图查看完整路线。

## 运行

环境要求：Xcode 26 或更新版本，iOS 17 或更新版本。

1. 用 Xcode 打开 `TurnCue.xcodeproj`。
2. 选择任意 iPhone Simulator。
3. 运行 `TurnCue` scheme。

命令行编译检查：

```sh
xcodebuild -project TurnCue.xcodeproj \
  -scheme TurnCue \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

核心模型的无界面检查：

```sh
swiftc TurnCue/Models/*.swift TurnCue/Fixtures/SampleRoute.swift Tests/CoreChecks.swift -o /tmp/turncue-core-checks
/tmp/turncue-core-checks
```

## 接下来验证什么

交互改动与人工验收清单见 [`docs/INTERACTION_POLISH.md`](docs/INTERACTION_POLISH.md)，产品验证见 [`docs/MVP.md`](docs/MVP.md)。当前版本是前台信息原型，不支持后台持续导航和偏航重算；自动地标只采用 MapKit 返回且靠近节点的兴趣点，仍需实地验证可信度。
