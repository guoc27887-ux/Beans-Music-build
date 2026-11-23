//
//  NetEaseMessagesView.swift
//  Beans
//
//  网易云私信界面，移植自 MeloX（https://github.com/youshen2/MeloX，GPL-3.0）。
//  原文件：MeloX/Features/Messages/NeteasePrivateMessagesView.swift、
//          NeteaseConversationView.swift、NeteaseMessageContactsView.swift。
//  改动：Observation 环境注入改为 Beans 的 @EnvironmentObject；当前用户 ID
//  直接取 AuthStore（MeloX 走 LibraryStore / accountProfile 接口）；文案改为
//  中文字面量；头像与封面复用 Beans 的 BeansAvatarView / CoverImage。
//  导航（2.0.19）：会话跳转用闭包式 NavigationLink，不用 value 路由加
//  navigationDestination。后者在真机上点开会话立即被弹回列表（2.0.18 实测），
//  闭包式与聚合页进私信列表的入口同款、已验证可用，不要改回去。
//  简化：MeloX 会话页会额外请求歌曲详情补全私信卡片封面，这里保留该逻辑；
//  分享资源到私信 / 动态（NeteaseShareSheet）不在本次移植范围内。
//

import SwiftUI

/// 「我的」页进入的网易云服务聚合页：私信 / 云盘 / 收藏专辑 / 关注歌手。
struct NetEaseHubView: View {
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        BeansNavigationStack {
            List {
                if auth.isLoggedIn {
                    NavigationLink {
                        NetEasePrivateMessagesView()
                    } label: {
                        hubRow(icon: "bubble.left.and.bubble.right", title: "网易云私信", subtitle: "查看和回复站内私信")
                    }
                    NavigationLink {
                        NetEaseCloudView()
                    } label: {
                        hubRow(icon: "externaldrive", title: "音乐云盘", subtitle: "云盘歌曲播放与上传")
                    }
                    NavigationLink {
                        NetEaseSubscribedAlbumsView()
                    } label: {
                        hubRow(icon: "square.stack", title: "收藏的专辑", subtitle: "同步网易云收藏专辑")
                    }
                    NavigationLink {
                        NetEaseFollowedArtistsView()
                    } label: {
                        hubRow(icon: "person.2", title: "关注的歌手", subtitle: "同步网易云关注歌手")
                    }
                } else {
                    EmptyStateView(icon: "person.crop.circle.badge.exclamationmark", text: "登录网易云后可用")
                }
            }
            .listStyle(.plain)
            .navigationTitle("网易云服务")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func hubRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.beansAmber)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BeansFont.appFont(15, .semibold))
                    .foregroundStyle(Color.beansLabel)
                Text(subtitle)
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 会话列表

struct NetEasePrivateMessagesView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var conversations: [NetEasePrivateConversation] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var currentUserID: Int { auth.user?.uid ?? 0 }

    var body: some View {
        Group {
            if isLoading, conversations.isEmpty {
                ProgressView("正在加载私信")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, conversations.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await load() }
                }
            } else if conversations.isEmpty {
                EmptyStateView(icon: "bubble.left.and.bubble.right", text: "暂无私信")
            } else {
                List {
                    ForEach(conversations) { conversation in
                        let contact = conversation.participant(currentUserID: currentUserID)
                        NavigationLink {
                            NetEaseConversationView(contact: contact) {
                                // 只有历史接口成功返回后才清除本地角标。首次历史
                                // 请求会同时在网易云服务端完成已读上报。
                                clearUnreadCount(for: contact.id)
                            }
                            .onDisappear {
                                Task { await load() }
                            }
                        } label: {
                            conversationRow(conversation, contact: contact)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await load() }
            }
        }
        .navigationTitle("网易云私信")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    NetEaseMessageContactsView()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("发起私信")
            }
        }
        .task { await load() }
    }

    private func conversationRow(_ conversation: NetEasePrivateConversation, contact: NetEaseMessageContact) -> some View {
        HStack(spacing: 12) {
            BeansAvatarView(remoteURL: contact.avatarURL, size: 52)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(contact.displayName)
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    Spacer()
                    if conversation.lastMessageTime > 0 {
                        Text(formattedTime(conversation.lastMessageTime))
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                    }
                }

                HStack {
                    Text(conversation.lastMessage.summary)
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(1)
                    Spacer()
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(BeansFont.appFont(11, .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedTime(_ milliseconds: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
        if Calendar.current.isDateInToday(date) {
            return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened))
        }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted))
    }

    private func clearUnreadCount(for contactID: Int) {
        guard let index = conversations.firstIndex(where: {
            $0.participant(currentUserID: currentUserID).id == contactID
        }) else { return }
        conversations[index].unreadCount = 0
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            conversations = try await NetEaseAPI.shared.privateMessageConversations()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - 会话页

struct NetEaseConversationView: View {
    let contact: NetEaseMessageContact
    var onMarkedRead: () -> Void = {}

    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var theme: ThemeStore

    @State private var messages: [NetEasePrivateMessage] = []
    @State private var resolvedSongArtworkURLs: [Int: URL] = [:]
    @State private var draft = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var sendError: String?
    @State private var selectedPlaylist: Playlist?
    @State private var selectedAlbum: Album?

    private var currentUserID: Int { auth.user?.uid ?? 0 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        messageRow(message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.last?.id) { _, messageID in
                guard let messageID else { return }
                withAnimation { proxy.scrollTo(messageID, anchor: .bottom) }
            }
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { composer }
        .overlay {
            if isLoading, messages.isEmpty {
                ProgressView("正在加载私信")
            } else if let errorMessage, messages.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await load() }
                }
            } else if !isLoading, messages.isEmpty {
                EmptyStateView(icon: "bubble.left", text: "暂无消息")
            }
        }
        .task(id: contact.id) { await load() }
        .alert("发送失败", isPresented: Binding(
            get: { sendError != nil },
            set: { if !$0 { sendError = nil } }
        )) {
            Button("好", role: .cancel) { sendError = nil }
        } message: {
            Text(sendError ?? "操作未完成")
        }
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistView(playlist: playlist)
                .environmentObject(player)
                .environmentObject(auth)
                .environmentObject(theme)
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(album: album)
                .environmentObject(player)
                .environmentObject(theme)
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("输入私信", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit { send() }

            Button {
                send()
            } label: {
                if isSending {
                    ProgressView().frame(width: 32, height: 32)
                } else {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
            }
            .disabled(trimmedDraft.isEmpty || isSending)
            .accessibilityLabel("发送")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func messageRow(_ message: NetEasePrivateMessage) -> some View {
        let isOutgoing = message.isOutgoing(currentUserID: currentUserID)
        return HStack {
            if isOutgoing { Spacer(minLength: 56) }
            VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 5) {
                messageContent(message.payload, isOutgoing: isOutgoing)
                if message.time > 0 {
                    Text(messageTime(message.time))
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
            }
            if !isOutgoing { Spacer(minLength: 56) }
        }
    }

    @ViewBuilder
    private func messageContent(_ payload: NetEasePrivateMessagePayload, isOutgoing: Bool) -> some View {
        if let resource = payload.resource {
            Button {
                open(resource)
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    if !payload.text.isEmpty {
                        Text(payload.text)
                            .foregroundStyle(isOutgoing ? .white : .primary)
                    }
                    HStack(spacing: 9) {
                        CoverImage(url: artworkURL(for: resource), size: 44, cornerRadius: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(resource.title)
                                .font(BeansFont.appFont(13, .medium))
                                .lineLimit(1)
                            Text(resource.kindTitle)
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(isOutgoing ? .white.opacity(0.75) : Color.beansComment)
                        }
                    }
                }
                .padding(10)
                .background(isOutgoing ? Color.accentColor : Color.beansGlassFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        } else {
            Text(payload.summary)
                .foregroundStyle(isOutgoing ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(isOutgoing ? Color.accentColor : Color.beansGlassFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func open(_ resource: NetEaseMessageResource) {
        switch resource.kind {
        case .song:
            if let song = resource.song {
                player.play(songs: [song], startAt: 0)
            }
        case .playlist:
            selectedPlaylist = resource.playlist
        case .album:
            selectedAlbum = resource.album
        }
    }

    private func artworkURL(for resource: NetEaseMessageResource) -> URL? {
        guard resource.kind == .song, let song = resource.song else { return resource.coverURL }
        return resolvedSongArtworkURLs[song.id] ?? resource.coverURL
    }

    private var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func messageTime(_ milliseconds: Int64) -> String {
        Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
            .formatted(Date.FormatStyle(date: .abbreviated, time: .shortened))
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await NetEaseAPI.shared.privateMessageHistory(userID: contact.id)
            messages = loaded
            isLoading = false
            onMarkedRead()
            await resolveSongArtwork(in: loaded)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    /// 私信卡片里的歌曲对象可能不带封面，补一次歌曲详情（同 MeloX 的处理）。
    private func resolveSongArtwork(in messages: [NetEasePrivateMessage]) async {
        let songIDs = Set(messages.compactMap { message -> Int? in
            guard let resource = message.payload.resource,
                  resource.kind == .song,
                  let song = resource.song,
                  song.id > 0,
                  song.coverURL == nil,
                  resolvedSongArtworkURLs[song.id] == nil else { return nil }
            return song.id
        })
        guard !songIDs.isEmpty else { return }
        if let songs = try? await NetEaseAPI.shared.songDetails(ids: Array(songIDs)) {
            for song in songs {
                if let url = song.coverURL {
                    resolvedSongArtworkURLs[song.id] = url
                }
            }
        }
    }

    private func send() {
        let content = trimmedDraft
        guard !content.isEmpty, !isSending else { return }
        isSending = true
        Task {
            defer { isSending = false }
            do {
                try await NetEaseAPI.shared.sendPrivateText(content, to: [contact.id])
                draft = ""
                await load()
            } catch is CancellationError {
                return
            } catch {
                sendError = error.localizedDescription
            }
        }
    }
}

// MARK: - 联系人（关注列表）

struct NetEaseMessageContactsView: View {
    @EnvironmentObject private var auth: AuthStore

    @State private var contacts: [NetEaseMessageContact] = []
    @State private var searchQuery = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading, contacts.isEmpty {
                ProgressView("正在加载联系人")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, contacts.isEmpty {
                ErrorStateView(message: errorMessage) {
                    Task { await load() }
                }
            } else if filteredContacts.isEmpty {
                EmptyStateView(icon: "person.2.slash", text: searchQuery.isEmpty ? "暂无可私信的联系人" : "未找到联系人")
            } else {
                List(filteredContacts) { contact in
                    NavigationLink {
                        NetEaseConversationView(contact: contact)
                    } label: {
                        HStack(spacing: 12) {
                            BeansAvatarView(remoteURL: contact.avatarURL, size: 48)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(contact.displayName)
                                    .font(BeansFont.appFont(15))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                if let signature = contact.signature?.trimmingCharacters(in: .whitespacesAndNewlines),
                                   !signature.isEmpty {
                                    Text(signature)
                                        .font(BeansFont.appFont(12))
                                        .foregroundStyle(Color.beansComment)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("发起私信")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchQuery, prompt: "搜索关注的人")
        .task { await load() }
    }

    private var filteredContacts: [NetEaseMessageContact] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return contacts }
        return contacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || $0.nickname.localizedCaseInsensitiveContains(query)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            guard let uid = auth.user?.uid else { throw NetEaseError.unknown("尚未登录网易云") }
            contacts = try await NetEaseAPI.shared.messageContacts(userID: uid)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
