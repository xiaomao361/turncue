import Foundation

// Keep these offline summaries aligned with docs/{guide,privacy,support,changelog}/.
enum HelpPage: String, CaseIterable, Identifiable, Hashable {
    case product, guide, privacy, support, changelog

    var id: String { rawValue }

    var title: String {
        switch self {
        case .product: "认识拐弯"
        case .guide: "使用说明"
        case .privacy: "隐私政策"
        case .support: "常见问题与支持"
        case .changelog: "版本记录"
        }
    }

    var symbol: String {
        switch self {
        case .product: "map"
        case .guide: "book"
        case .privacy: "hand.raised"
        case .support: "questionmark.circle"
        case .changelog: "clock"
        }
    }

    var introduction: String {
        switch self {
        case .product: "先看懂路线，再出发。"
        case .guide: "出发前看整条路，到了关键位置再确认下一步。"
        case .privacy: "更新日期：2026 年 9 月 7 日。适用于当前原型。"
        case .support: "遇到问题时，可以先检查下面几项。"
        case .changelog: "安装版本：\(AppInformation.version)。以下记录描述原型进展，不代表 App Store 已发布。"
        }
    }

    var sections: [HelpSection] {
        switch self {
        case .product:
            [
                HelpSection("把路线装进心里", "走哪条路，经过什么地标，在哪里转弯。拐弯把完整路线整理为最多 7 个关键节点；短路线可能更少。先形成整体方向感，再到关键位置确认。"),
                HelpSection("找到目的地", "输入地点，核对名称、地址与距离。结果不合适时可以扩大搜索范围，或直接在地图上选点。当前从你所在的位置出发。"),
                HelpSection("带上这张图", "在前台跟随、暂停、继续或退回上一节点。也可以生成路线图片，通过系统分享面板保存或发送；需要详细导航时交给 Apple 地图。"),
                HelpSection("仍在打磨的原型", "当前不提供偏航重算、后台持续导航或锁屏提示。骑行覆盖与地标可靠性取决于地图服务和现场情况。公开下载渠道尚未公布。")
            ]
        case .guide:
            [
                HelpSection("1. 找到目的地", "允许使用期间定位，输入地点并核对地址与距离。补充城区、道路或建筑全名可以缩小范围。地图选点用于选择目的地，生成真实路线仍需要当前位置。"),
                HelpSection("2. 选择出行方式", "确认目的地后，选择步行、驾车或骑行，也可以按距离推荐。搜索与路线生成期间可以取消，修改搜索词会丢弃旧请求结果。"),
                HelpSection("3. 看路线和节点", "地图保留完整路线，只突出少量关键节点。轻点地图节点或路线索引，查看怎么到这里、到达以后怎么走。地标不足时会使用道路或路口名称。"),
                HelpSection("4. 在前台跟随", "跟随时仍能看到整张路线。可以暂停、继续或退回上一节点。进入最后一段不等于已经到达；实际抵达目的地后，请手动确认完成。"),
                HelpSection("5. 保存或分享", "“分享图”生成包含地图、路线、目的地和节点说明的静态图片，再交给系统分享面板。图片不会随你的位置更新。分享前检查是否包含私人地点。"),
                HelpSection("需要完整导航时", "选择“在 Apple 地图中查看”，会传递起点、终点与出行方式。Apple 地图可能根据当前条件生成不同的路线。"),
                HelpSection("使用边界", "搜索、路线和地图快照需要联网。当前没有偏航重算、后台持续导航、逐转弯语音或锁屏提示。地标不保证在实际视野中可见；时间与距离均为估算。道路标志和现场状况优先，驾车或骑行时请安全停下后操作。")
            ]
        case .privacy:
            [
                HelpSection("无需账号，不进行跨 App 跟踪", "当前版本没有账号、云同步、开发者自建的数据接收服务、广告 SDK 或第三方分析 SDK。"),
                HelpSection("位置权限", "允许定位后，App 使用当前位置查找附近目的地、计算起点和在前台跟随路线。仅请求使用期间定位，不提供后台持续导航。可以在系统定位设置中调整或关闭权限；关闭后，依赖当前位置的功能将不可用。"),
                HelpSection("地图请求需要联网", "地点补全、搜索、路线计算、附近地标和地图快照使用 Apple MapKit。搜索词、搜索区域、起终点坐标与出行方式按请求需要交给地图服务处理，并非所有处理都只在本机完成。Apple 及当地服务提供方的数据处理遵循其隐私政策。开发者不会通过自建服务器接收这些请求。"),
                HelpSection("路线状态与保留", "当前没有路线历史数据库。搜索结果、路线和跟随状态供当前运行使用，不提供长期路线历史查询。操作系统与地图服务可能管理自己的缓存，这不等同于开发者保存路线历史。"),
                HelpSection("主动分享与跳转", "主动使用系统分享面板时，路线图片才会交给所选 App、服务或保存位置。图片可能包含起点、目的地和私人地点。结束路线或卸载 App 不会删除相册、文件或接收方已有的副本，需到对应位置单独管理。\n\n“在 Apple 地图中查看”会传递起点、终点与出行方式；后续处理遵循 Apple 地图的设置与政策。"),
                HelpSection("支持邮件与网站", "主动联系开发者时，邮件服务会传输邮件地址、正文与附件，开发者用它们回复和排查问题。请勿发送私人住址或完整轨迹；需要处理已发送的信息，可联系支持邮箱。\n\n官网不嵌入统计脚本、广告、外部字体或跟踪 Cookie。计划由 GitHub Pages 托管，托管方可能处理 IP 地址等访问日志。"),
                HelpSection("更新与联系", "如果后续加入账号、持久化存储、云服务或分析功能，会在相关版本发布前更新说明。隐私问题请联系 \(AppInformation.supportEmail)。")
            ]
        case .support:
            [
                HelpSection("无法获取当前位置？", "检查系统定位服务与拐弯的使用期间定位权限。到开阔处重试；精确位置关闭或定位信号较弱可能影响起点与节点判断。可从“关于与帮助”的定位设置入口进入系统设置。"),
                HelpSection("找不到地点或路线生成失败？", "补充城区、道路或建筑名称，核对地址与距离，也可以扩大范围或地图选点。检查网络，取消后重试，必要时换一个目的地或出行方式。地图服务无法提供的路线，拐弯无法自行补全。"),
                HelpSection("骑行路线不可用？", "骑行取决于当地地图覆盖。不要把步行或驾车路线直接当作骑行指引。"),
                HelpSection("走偏或锁屏后会继续导航吗？", "当前没有偏航重算、后台持续导航或锁屏提示。需要完整导航时，请使用“在 Apple 地图中查看”。"),
                HelpSection("地标找不到，或节点提前前进？", "地标来自地图兴趣点，可能不在视野中。在安全位置核对周围道路，可暂停跟随或退回上一节点；必要时查看完整导航。"),
                HelpSection("为什么最后一段还没完成？", "最后一段仍可能有路要走。实际抵达目的地后，请手动确认到达。"),
                HelpSection("分享失败，或图片没有实时进度？", "地图快照需要网络，失败后请联网重试。分享图是静态图片，没有实时位置或双方进度同步。取消系统分享面板不会发送图片。"),
                HelpSection("如何清理数据？", "当前没有路线历史数据库。自行保存的图片需在相册或文件中删除，已发出的图片由接收方及所用服务管理。"),
                HelpSection("反馈时带上哪些信息？", "请提供 iPhone 型号、iOS 版本、App 版本、出行方式、操作步骤与预期和实际结果。地图覆盖问题提供城市或公开地标即可；截图请遮挡私人住址与精确起点。")
            ]
        case .changelog:
            [
                HelpSection("0.4 · 原型", "工程基线 0.4 (4)。地点建议、按距离排列的搜索结果、扩大范围和地图选点；支持选择步行、驾车和骑行。完整路线配合最多 7 个关键节点，提供方向、地标与到达后动作。"),
                HelpSection("跟随与分享", "支持前台跟随、暂停、继续、退回上一节点和手动确认到达。可生成路线图片或交给 Apple 地图。"),
                HelpSection("关于与帮助", "新增离线产品介绍、使用说明、隐私政策、常见问题与版本记录；可查看定位权限、打开系统设置和准备反馈邮件。界面版本号取自当前安装包。"),
                HelpSection("仍待验证", "不同城市的地标可信度、骑行覆盖、实际试走体验，以及 VoiceOver 和大字体的真机表现。当前未提供偏航重算、后台持续导航、锁屏提示、账号与云同步。")
            ]
        }
    }
}

struct HelpSection: Identifiable {
    let title: String
    let text: String
    var id: String { title }

    init(_ title: String, _ text: String) {
        self.title = title
        self.text = text
    }
}
