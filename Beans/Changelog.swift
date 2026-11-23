import SwiftUI

// MARK: - 版本更新日志（设置页与首次更新弹窗使用）

struct VersionLog: Identifiable {
    let id: String
    let version: String
    let title: String
    let notices: [String]
    let features: [String]
    let fixes: [String]
    let imageURL: URL?
    let textColorHex: String?

    init(id: String, version: String, title: String, notices: [String] = [], features: [String], fixes: [String], imageURL: URL? = nil, textColorHex: String? = nil) {
        self.id = id
        self.version = version
        self.title = title
        self.notices = notices
        self.features = features
        self.fixes = fixes
        self.imageURL = imageURL
        self.textColorHex = textColorHex
    }
}

enum ChangelogStore {
    static let lastSeenKey = "beans.lastSeenVersion"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var lastSeenVersion: String {
        UserDefaults.standard.string(forKey: lastSeenKey) ?? ""
    }

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenKey)
        UserDefaults.standard.synchronize()
    }

    static var shouldShowWhatsNew: Bool {
        lastSeenVersion != currentVersion
    }

    static var latest: VersionLog? { logs.first }

    /// 更新日志从 GitHub Releases 读取；网络不可用时继续显示内置历史记录。
    static func fetchRemoteLatest() async -> VersionLog? {
        guard let remote = try? await UpdateChecker.fetchLatest() else { return nil }
        return versionLog(from: remote)
    }

    static func fetchRemoteHistory() async -> [VersionLog] {
        guard let remoteLogs = try? await UpdateChecker.fetchHistory() else { return [] }
        return remoteLogs.map { versionLog(from: $0) }
    }

    private static func versionLog(from remote: UpdateChecker.ReleaseInfo) -> VersionLog {
        let notes = remote.body
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return VersionLog(
            id: "server-\(remote.version)",
            version: remote.version,
            title: remote.name,
            features: notes,
            fixes: [],
            imageURL: remote.notesImageURL,
            textColorHex: remote.notesTextColorHex
        )
    }

    /// 内置历史记录。注意：发新版时先在数组顶部补上新版本条目再升版本号，
    /// 否则更新说明弹窗在远端拉取失败时展示的仍是旧版本条目（logs.first）。
    static let logs: [VersionLog] = [
        VersionLog(
            id: "2.0.19",
            version: "2.0.19",
            title: "私信会话打不开修复",
            features: [],
            fixes: [
                "修复网易云私信点开会话立刻退回列表：会话跳转改用与网易云服务入口相同的导航方式"
            ]
        ),
        VersionLog(
            id: "2.0.18",
            version: "2.0.18",
            title: "汽水扫码放行等待",
            features: [],
            fixes: [
                "移除「官方网页登录」（汽水没有浏览器登录页：官网只有下载页，授权链接浏览器打开是 404）",
                "扫码确认后改为耐心等待服务端放行：每分钟只查一次、最长等 15 分钟，不再密集轮询撞限频",
                "「我的」页移除上游推广入口：交流群、自愿赞助、点我有惊喜"
            ]
        ),
        VersionLog(
            id: "2.0.17",
            version: "2.0.17",
            title: "汽水网页登录修正",
            features: [],
            fixes: [
                "「用官方网页登录」改开真正的官方授权页（2.0.16 打开的是汽水官网下载宣传页，根本没有登录入口）"
            ]
        ),
        VersionLog(
            id: "2.0.16",
            version: "2.0.16",
            title: "汽水官方网页登录",
            features: [
                "汽水登录页新增「用官方网页登录」：在应用内打开汽水官网登录（扫码或手机号），登录成功后自动同步登录态，绕开扫码轮询被服务端限频锁死的问题"
            ],
            fixes: []
        ),
        VersionLog(
            id: "2.0.15",
            version: "2.0.15",
            title: "汽水扫码短信验证补全",
            features: [
                "汽水扫码后账号触发短信验证时，可在应用内完成：接收验证码填写提交，或按提示发送上行短信后确认"
            ],
            fixes: [
                "汽水登录限频退避（2.0.14 同内容）：扫码确认后轮询撞限频改为退避 60 秒再查"
            ]
        ),
        VersionLog(
            id: "2.0.14",
            version: "2.0.14",
            title: "汽水登录限频退避",
            features: [],
            fixes: [
                "汽水扫码确认后登录不落地：轮询撞上服务端限频（error_code 7）后改为退避 60 秒再查，不再每 2.5 秒硬打把冷却顶回去（依据真机诊断日志定位）"
            ]
        ),
        VersionLog(
            id: "2.0.13",
            version: "2.0.13",
            title: "汽水主页排行榜补齐与登录诊断",
            features: [],
            fixes: [
                "汽水主页排行榜在简洁样式下不显示条目（只剩标题）",
                "汽水扫码改用官方扫码登录链接出码（此前展示的服务端图片码能确认但不下发登录会话），并加入登录轮询日志便于定位"
            ]
        ),
        VersionLog(
            id: "2.0.12",
            version: "2.0.12",
            title: "汽水主页平台与登录修复",
            features: [
                "主页平台新增汽水音乐：每日推荐、推荐歌单与官方排行榜（热歌榜、新歌榜、欧美榜、音乐人歌曲榜）"
            ],
            fixes: [
                "汽水扫码确认后仍不登录：登录请求的参数与请求头补齐到官方网页端 SDK 的完整形态（之前的精简参数能出码能确认，但服务端不下发登录会话）"
            ]
        ),
        VersionLog(
            id: "2.0.10",
            version: "2.0.10",
            title: "汽水扫码登录落地修复",
            features: [],
            fixes: [
                "修复汽水扫码后登录态不落地的问题：确认后跟随服务端跳转领取会话，并补齐会话识别与登录过程中的 Cookie 累积"
            ]
        ),
        VersionLog(
            id: "2.0.9",
            version: "2.0.9",
            title: "汽水登录二维码修复",
            features: [],
            fixes: [
                "修复汽水扫码登录二维码显示空白的问题（服务端下发的是二维码图片，之前误当文本处理）",
                "汽水搜单曲新增安卓端搜索兜底：网页端搜索无结果时自动换一条通道再搜"
            ]
        ),
        VersionLog(
            id: "2.0.8",
            version: "2.0.8",
            title: "汽水音乐改直连与扫码登录",
            features: [
                "汽水音乐搜索改直连官方接口：搜歌、搜歌单、搜专辑、歌手",
                "汽水歌单详情与推荐歌单改直连",
                "汽水歌词改直连，逐字歌词自动转换为标准歌词格式",
                "汽水评论改直连",
                "汽水每日推荐接通（发现页）",
                "新增汽水扫码登录（入口在「我的」页），登录后可在资料库查看「我的汽水歌单」"
            ],
            fixes: [
                "修复汽水搜索因上游网关故障一直返回空结果的问题（改直连后不再依赖网关）"
            ]
        ),
        VersionLog(
            id: "2.0.7",
            version: "2.0.7",
            title: "网易云私信、云盘与听歌识曲",
            features: [
                "新增网易云私信，可查看会话并聊天（入口在「我的」页「网易云服务」）",
                "新增音乐云盘，可播放云盘歌曲并上传本地音乐",
                "新增听歌识曲，通过麦克风识别歌曲（入口在搜索页页头）",
                "新增网易云收藏专辑与关注歌手，歌手页可直接关注或取消关注",
                "复制网易云歌曲、歌单、专辑或一起听邀请链接后切回应用，自动弹窗直达",
                "新增对唱歌词分行，对唱歌曲按演唱者分行显示（Folia 歌词 Classic 与 Still 样式）",
                "新增雷达歌单，歌单广场展示私人、华语、欧美、日系雷达（需登录网易云）",
                "新增订阅收藏他人歌单，可在歌单详情页收藏或取消收藏",
                "新增听歌上报，播放时自动同步网易云最近播放与听歌排行"
            ],
            fixes: []
        ),
        VersionLog(
            id: "2.0.6",
            version: "2.0.6",
            title: "播放队列流畅度修复",
            features: [],
            fixes: [
                "修复播放队列滑动严重掉帧、行与行重叠糊化的问题（列表改为懒加载，封面按显示尺寸解码）"
            ]
        ),
        VersionLog(
            id: "2.0.5",
            version: "2.0.5",
            title: "搜索页跳动修复与评论按钮",
            features: [
                "经典播放器样式新增可见的评论按钮（原上划打开评论的手势保留）"
            ],
            fixes: [
                "修复搜索页内容周期性上漂、约每 1.5 秒整复位的跳动问题（歌单页同源问题一并覆盖）"
            ]
        ),
        VersionLog(
            id: "2.0.4",
            version: "2.0.4",
            title: "一起听入口补齐与页面抖动修复",
            features: [
                "「一起听」入口补齐全部播放器样式（此前仅经典样式的播放器菜单有入口）"
            ],
            fixes: [
                "修复搜索页、歌单页的页面抖动"
            ]
        ),
        VersionLog(
            id: "2.0.3",
            version: "2.0.3",
            title: "iOS 18 适配版",
            features: [
                "适配 iOS 18（上游原版最低要求 iOS 26.1）",
                "新增「一起听」，通过网易云官方接口与朋友同步听歌"
            ],
            fixes: [
                "修复多平台聚合音源无法放歌的问题"
            ]
        ),
        VersionLog(
            id: "1.8.1",
            version: "1.8.1",
            title: "动态壁纸与听歌统计优化",
            features: [
                "新增 Star Nest、Dot Orbit、Dots 与 Grain Gradient 壁纸",
                "Grain Gradient 按静态壁纸处理，支持颜色、缩放和对比度调节",
                "我的界面仅保留听歌时长显示"
            ],
            fixes: [
                "听歌时长改为按实际播放中的经过时间计算，暂停、缓冲和切歌间隙不再计入",
                "修复拖动进度、循环播放或反复测试同一首歌导致听歌时长异常增加的问题"
            ]
        ),
        VersionLog(
            id: "1.8",
            version: "1.8",
            title: "专辑浏览体验优化",
            features: [
                "新增“该歌手的其他专辑”加载预览动效",
                "继续复用专辑与封面缓存，减少重复加载时的空白闪烁"
            ],
            fixes: [
                "修复详情页封面缓存刷新时短暂发白的问题",
                "修复排行榜作者头像刷新时短暂消失的问题"
            ]
        ),
        VersionLog(
            id: "1.7.01",
            version: "1.7.01",
            title: "流畅性与稳定性优化",
            notices: [
                "重点：本次优化高刷新渲染、列表滚动和更新说明加载体验。"
            ],
            features: [
                "优化封面加载中的扫光渲染，减少列表快速滚动时的主线程负担",
                "高刷新率请求覆盖主界面、弹窗与全屏播放器",
                "设置底部补充完整运行环境信息"
            ],
            fixes: [
                "修复更新后首次打开更新说明短暂显示旧版 1.6.7 内容的问题",
                "修复自定义视频头像在覆盖更新后可能丢失的问题"
            ]
        ),
        VersionLog(
            id: "1.6.7",
            version: "1.6.7",
            title: "主页、播放器与缓存体验优化",
            notices: [
                "建议更新时卸载后重新安装，不要覆盖安装，否则可能出现部分问题。",
                "不是最新版请不要反馈问题，旧版本不再维护。",
                "本软件不提供下载服务，请支持官方网易云音乐、QQ 音乐和酷狗音乐平台。"
            ],
            features: [
                "新增“新碟上架”和“歌手”板块",
                "新增歌单搜索，并将歌单广场独立为单独页面",
                "“我的”入口移至右上角，支持自定义昵称和头像",
                "新增灵动岛与控制中心显示开关",
                "新增多项缓存机制，提升加载速度和使用体验",
                "优化底部栏动画，适配 Apple Music 风格的自动收缩效果",
                "Apple Music 风格主页新增磨砂背景",
                "账号入口移至设置页面",
                "修改默认强调色",
                "优化音源播放与切歌速度",
                "更新底部栏图标样式",
                "移除歌单液态容器"
            ],
            fixes: [
                "修复低版本系统无法调节进度条的问题",
                "修复歌词与音乐进度不同步的问题",
                "修复自定义排序后重新打开应用失效的问题"
            ]
        ),
        VersionLog(
            id: "1.6.6",
            version: "1.6.6",
            title: "歌单广场与播放体验优化",
            features: [
                "新增网易云和 QQ 音乐歌单广场搜索功能",
                "优化歌曲封面缓存",
                "优化歌词滑动后不返回当前播放位置的问题",
                "优化整体流畅性，低系统表现以实际测试为准",
                "优化网易云私人漫游问题，遇到问题可使用心动模式",
                "简化搜索界面，移除均衡器注释",
                "更换酷狗音乐歌单广场接口",
                "整体以优化和问题修复为主"
            ],
            fixes: [
                "修复 QQ 音乐本身有会员但无法播放的问题",
                "修复 iOS 26 以下系统无法返回的问题"
            ]
        ),
        VersionLog(
            id: "1.6.5.1",
            version: "1.6.5.1",
            title: "音源与歌单体验修复",
            features: [
                "修复歌单页播放器无法返回的问题",
                "删除内置音源功能和填写密钥（可从密钥后台复制链接导入）",
                "持续优化 QQ 音源问题",
                "增加歌单、主页和排行榜缓存，减少重复加载"
            ],
            fixes: [
                "软件不提供任何下载服务，不会导入音源的可在群里反馈"
            ]
        ),
        VersionLog(
            id: "1.6.5",
            version: "1.6.5",
            title: "音源播放修复",
            features: [
                "新增网易云免费音源"
            ],
            fixes: [
                "修复 QQ 音乐音源不能播放的问题",
                "修复自定义导入音源不能播放的问题"
            ]
        ),
    ]
}

// MARK: - 更新说明弹窗

struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remoteLog: VersionLog?
    @State private var isLoading = true

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    if let log = remoteLog {
                        VersionLogCard(log: log)
                            .padding(16)
                    } else if isLoading {
                        ProgressView()
                            .tint(Color.beansAmber)
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else if let log = ChangelogStore.latest {
                        VersionLogCard(log: log)
                            .padding(16)
                    }
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始使用") {
                        ChangelogStore.markSeen()
                        dismiss()
                    }
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansAmber)
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large]))
        .task {
            remoteLog = await ChangelogStore.fetchRemoteLatest()
            isLoading = false
        }
        .onDisappear {
            ChangelogStore.markSeen()
        }
    }
}

struct ChangelogListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var remoteLogs: [VersionLog] = []
    @State private var isLoading = true

    var body: some View {
        let remoteVersions = Set(remoteLogs.map(\.version))
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    if isLoading {
                        ProgressView()
                            .tint(Color.beansAmber)
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(remoteLogs) { log in
                                VersionLogCard(log: log)
                            }
                            ForEach(ChangelogStore.logs.filter { log in
                                !remoteVersions.contains(log.version)
                            }) { log in
                                VersionLogCard(log: log)
                            }
                        }
                        .padding(16)
                    }
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large]))
        .task {
            remoteLogs = await ChangelogStore.fetchRemoteHistory()
            isLoading = false
        }
    }
}

private struct VersionLogCard: View {
    let log: VersionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("v\(log.version)")
                    .font(BeansFont.appFont(16, .bold))
                    .foregroundStyle(Color.beansAmber)
                Text(log.title)
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(textColor)
            }
            if let imageURL = log.imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        EmptyView()
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 80)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !log.notices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(log.notices, id: \.self) { notice in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.top, 1)
                            Text(notice)
                                .font(BeansFont.appFont(13, .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.red.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            if !log.features.isEmpty {
                logSection(title: "新增功能", icon: "plus.circle.fill", items: log.features)
            }
            if !log.fixes.isEmpty {
                Divider().overlay(Color.beansComment.opacity(0.15))
                logSection(title: "问题修复", icon: "checkmark.circle.fill", items: log.fixes)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .beansCardShadow(radius: 9, y: 3)
    }

    private func logSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(BeansFont.appFont(14, .bold))
                .foregroundStyle(Color.beansAmber)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansAmber)
                        .padding(.top, 2)
                    Text(LocalizedStringKey(item))
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var textColor: Color {
        if let raw = log.textColorHex, let color = Color(hex: raw) { return color }
        return Color.beansLabel
    }
}
