import Foundation

public struct XcodeRule: CategoryRule {
    public let id = CategoryID.xcode
    public init() {}

    public func scan(_ env: ScanEnvironment) async -> [Item] {
        let xcode = env.home.appending("Library/Developer/Xcode")
        var items = childrenAsItems(of: xcode.appending("DerivedData"), category: id, action: .delete,
                                    preselected: true, env: env, name: Self.projectName)
        for platform in ["iOS", "watchOS", "macOS", "tvOS", "visionOS"] {
            items += childrenAsItems(of: xcode.appending("\(platform) DeviceSupport"), category: id, action: .delete,
                                     preselected: true, env: env, name: { "\(platform) \($0.lastPathComponent)" })
        }
        let userData = xcode.appending("UserData")
        if let previews = makeItem(userData.appending("Previews"), root: userData, name: "Previews",
                                   category: id, action: .delete, preselected: true, env: env) {
            items.append(previews)
        }
        let archives = xcode.appending("Archives")
        for day in children(of: archives) {
            items += children(of: day).filter { $0.pathExtension == "xcarchive" }.compactMap {
                makeItem($0, root: archives, name: $0.deletingPathExtension().lastPathComponent,
                         category: id, action: .trash, preselected: false, env: env)
            }
        }
        return items
    }

    /// DerivedData folders are named `Project-<28 letter hash>`.
    static func projectName(_ url: URL) -> String {
        let name = url.lastPathComponent
        guard let dash = name.lastIndex(of: "-"), name.distance(from: dash, to: name.endIndex) > 20 else { return name }
        return String(name[..<dash])
    }
}
