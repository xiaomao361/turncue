import Foundation

/// Public destinations stay here so release configuration has one owner.
enum AppInformation {
    static let supportEmail = "zhouwei@linux.com"
    static let website = URL(string: "https://xiaomao361.github.io/turncue/")!
    static let repository = URL(string: "https://github.com/xiaomao361/turncue")!
    static let appleMapsPrivacy = URL(string: "https://www.apple.com/legal/privacy/data/en/apple-maps/")!
    static let githubPrivacy = URL(string: "https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement")!

    // Enable only after the public pages have been deployed and checked.
    static let websiteIsPublished = false

    static var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        return "\(version) (\(build))"
    }

    static var supportMailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "TurnCue 使用反馈"),
            URLQueryItem(name: "body", value: "App 版本：\(version)\n\niPhone 型号与 iOS 版本：\n出行方式：\n操作步骤：\n预期结果：\n实际结果：\n\n请勿附上私人住址、精确起点或完整私人路线。")
        ]
        return components.url
    }
}
