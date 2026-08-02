import AMSMB2
import Darwin
import Foundation
import NetFS
import Security
import SwiftUI

private let smbVideoExtensions: Set<String> = [
    "3gp", "asf", "avi", "flv", "m2ts", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "mts", "ts", "vob", "webm", "wmv"
]

struct SMBEntry: Identifiable, Hashable, Sendable {
    let path: String
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modifiedAt: Date

    var id: String { path }
    var isVideo: Bool { !isDirectory && smbVideoExtensions.contains((name as NSString).pathExtension.lowercased()) }
}

struct SMBDiscoveredServer: Identifiable, Hashable, Sendable {
    let serviceName: String
    let host: String
    let port: Int

    var id: String { "\(serviceName)|\(host)|\(port)" }
    var address: String { port == 445 ? host : "\(host):\(port)" }
}

@MainActor
private final class SMBDiscoveryController: NSObject, @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {
    private let browser = NetServiceBrowser()
    private var resolving: [String: NetService] = [:]
    private var found: [String: SMBDiscoveredServer] = [:]
    private let onUpdate: ([SMBDiscoveredServer]) -> Void

    init(onUpdate: @escaping ([SMBDiscoveredServer]) -> Void) {
        self.onUpdate = onUpdate
        super.init()
        browser.delegate = self
    }

    func start() {
        stop()
        found = [:]
        browser.searchForServices(ofType: "_smb._tcp.", inDomain: "local.")
    }

    func stop() {
        browser.stop()
        for service in resolving.values { service.stop() }
        resolving = [:]
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let key = "\(service.name)|\(service.domain)"
        resolving[key] = service
        service.delegate = self
        service.resolve(withTimeout: 5)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let prefix = "\(service.name)|"
        found = found.filter { !$0.key.hasPrefix(prefix) }
        publish()
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        let host = numericIPv4Address(from: sender.addresses ?? [])
            ?? (sender.hostName ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard !host.isEmpty else { return }
        let item = SMBDiscoveredServer(serviceName: sender.name, host: host, port: sender.port)
        found[item.id] = item
        resolving.removeValue(forKey: "\(sender.name)|\(sender.domain)")
        publish()
    }

    private func publish() {
        onUpdate(found.values.sorted {
            $0.serviceName.localizedStandardCompare($1.serviceName) == .orderedAscending
        })
    }
}

private func numericIPv4Address(from addresses: [Data]) -> String? {
    for data in addresses {
        guard data.count >= MemoryLayout<sockaddr_in>.size else { continue }
        var address = sockaddr_in()
        _ = withUnsafeMutableBytes(of: &address) { destination in
            data.copyBytes(to: destination)
        }
        guard Int32(address.sin_family) == AF_INET else { continue }
        var bytes = address.sin_addr
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &bytes, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else { continue }
        return buffer.withUnsafeBufferPointer { pointer in
            String(cString: pointer.baseAddress!)
        }
    }
    return nil
}

enum SMBSortOrder: String, CaseIterable, Identifiable {
    case modifiedDescending
    case nameAscending
    case sizeDescending

    var id: String { rawValue }
    var title: String {
        switch self {
        case .modifiedDescending: return "修改时间（新到旧）"
        case .nameAscending: return "名称（A–Z）"
        case .sizeDescending: return "大小（大到小）"
        }
    }
}

enum SMBInputError: LocalizedError {
    case invalidServer
    case missingShare
    case invalidSelection
    case mountFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidServer: return "服务器地址无效。请填写主机名、IP，或 smb:// 地址。"
        case .missingShare: return "请填写共享名称。"
        case .invalidSelection: return "请选择一个视频文件。"
        case .mountFailed(let code): return "macOS 挂载 SMB 共享失败（错误码 \(code)）。"
        }
    }
}

private enum SMBKeychain {
    static let service = "app.captionflow.desktop.smb"

    static func password(for account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(password: String, for account: String) throws {
        let identity: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let data = Data(password.utf8)
        let status = SecItemUpdate(identity as CFDictionary, [kSecValueData: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = identity
            item[kSecValueData] = data
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus)) }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func removePassword(for account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

private struct SMBEndpoint: Sendable {
    let serverURL: URL
    let hostLabel: String

    init(_ input: String) throws {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SMBInputError.invalidServer }
        let candidate = trimmed.contains("://") ? trimmed : "smb://\(trimmed)"
        guard var components = URLComponents(string: candidate),
              components.scheme?.lowercased() == "smb", components.host?.isEmpty == false else {
            throw SMBInputError.invalidServer
        }
        components.user = nil
        components.password = nil
        components.path = ""
        components.query = nil
        components.fragment = nil
        guard let url = components.url else { throw SMBInputError.invalidServer }
        serverURL = url
        hostLabel = components.host ?? trimmed
    }
}

@MainActor
final class SMBBrowserModel: ObservableObject {
    @Published var server: String
    @Published var share: String
    @Published var domain: String
    @Published var username: String
    @Published var password = ""
    @Published var rememberPassword = true
    @Published var currentPath = ""
    @Published var entries: [SMBEntry] = []
    @Published var selectedPath: String?
    @Published var searchText = ""
    @Published var sortOrder: SMBSortOrder = .modifiedDescending
    @Published var isConnected = false
    @Published var isBusy = false
    @Published var status = "填写 SMB 服务器和共享名称后连接。"
    @Published var discoveredServers: [SMBDiscoveredServer] = []
    @Published var isDiscovering = false

    private var manager: SMB2Manager?
    private let defaults = UserDefaults.standard
    private var discovery: SMBDiscoveryController?

    init() {
        server = UserDefaults.standard.string(forKey: "smb.server") ?? ""
        share = UserDefaults.standard.string(forKey: "smb.share") ?? ""
        domain = UserDefaults.standard.string(forKey: "smb.domain") ?? ""
        username = UserDefaults.standard.string(forKey: "smb.username") ?? ""
        discovery = SMBDiscoveryController { [weak self] servers in
            self?.discoveredServers = servers
            self?.isDiscovering = false
        }
    }

    var visibleEntries: [SMBEntry] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = entries.filter { entry in
            (entry.isDirectory || entry.isVideo) && (needle.isEmpty || entry.name.localizedCaseInsensitiveContains(needle))
        }
        return filtered.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            switch sortOrder {
            case .modifiedDescending:
                if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt > rhs.modifiedAt }
            case .nameAscending:
                break
            case .sizeDescending:
                if lhs.size != rhs.size { return lhs.size > rhs.size }
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    var selectedEntry: SMBEntry? {
        guard let selectedPath else { return nil }
        return entries.first { $0.path == selectedPath }
    }

    var breadcrumb: String { currentPath.isEmpty ? "/" : "/\(currentPath)" }

    func startDiscovery() {
        discoveredServers = []
        isDiscovering = true
        discovery?.start()
    }

    func stopDiscovery() {
        discovery?.stop()
        isDiscovering = false
    }

    func useDiscoveredServer(_ item: SMBDiscoveredServer) {
        server = item.address
        status = "已选择 \(item.serviceName)。请填写共享名称和账号后连接。"
    }

    func connect() {
        guard !isBusy else { return }
        isBusy = true
        status = "正在连接 SMB 服务器…"
        Task {
            do {
                let endpoint = try SMBEndpoint(server)
                let cleanShare = share.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanShare.isEmpty else { throw SMBInputError.missingShare }
                let account = keychainAccount(endpoint: endpoint, share: cleanShare)
                let secret = password.isEmpty ? (SMBKeychain.password(for: account) ?? "") : password
                let credential = URLCredential(
                    user: username.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: secret,
                    persistence: .forSession
                )
                guard var newManager = SMB2Manager(url: endpoint.serverURL, domain: domain, credential: credential) else {
                    throw SMBInputError.invalidServer
                }
                newManager.timeout = 30
                do {
                    try await newManager.connectShare(name: cleanShare)
                } catch {
                    // libsmb2 can transiently select an unavailable interface on the first attempt.
                    try await Task.sleep(for: .milliseconds(350))
                    guard let retryManager = SMB2Manager(url: endpoint.serverURL, domain: domain, credential: credential) else {
                        throw error
                    }
                    retryManager.timeout = 30
                    try await retryManager.connectShare(name: cleanShare)
                    newManager = retryManager
                }
                manager = newManager
                currentPath = ""
                isConnected = true
                password = secret
                saveNonSecretSettings()
                if rememberPassword, !secret.isEmpty {
                    try SMBKeychain.save(password: secret, for: account)
                } else if !rememberPassword {
                    SMBKeychain.removePassword(for: account)
                }
                try await loadDirectory()
            } catch {
                isConnected = false
                manager = nil
                status = error.localizedDescription
            }
            isBusy = false
        }
    }

    func refresh() {
        guard manager != nil, !isBusy else { return }
        isBusy = true
        Task {
            do { try await loadDirectory() }
            catch { status = error.localizedDescription }
            isBusy = false
        }
    }

    func open(_ entry: SMBEntry) {
        guard entry.isDirectory, !isBusy else { return }
        currentPath = entry.path
        selectedPath = nil
        refresh()
    }

    func goUp() {
        guard !currentPath.isEmpty, !isBusy else { return }
        currentPath = (currentPath as NSString).deletingLastPathComponent
        if currentPath == "." || currentPath == "/" { currentPath = "" }
        selectedPath = nil
        refresh()
    }

    func mountedURLForSelection() async throws -> URL {
        guard let selectedEntry, selectedEntry.isVideo else { throw SMBInputError.invalidSelection }
        let endpoint = try SMBEndpoint(server)
        let cleanShare = share.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanShare.isEmpty else { throw SMBInputError.missingShare }
        let account = keychainAccount(endpoint: endpoint, share: cleanShare)
        let secret = password.isEmpty ? (SMBKeychain.password(for: account) ?? "") : password
        let mountUsername = username
        if let mounted = existingMountedSMBShare(
            for: endpoint.serverURL.appendingPathComponent(cleanShare),
            username: mountUsername
        ) {
            return mounted.appendingPathComponent(selectedEntry.path)
        }
        let mountRoot = try await Task.detached(priority: .userInitiated) {
            try mountSMBShare(serverURL: endpoint.serverURL, share: cleanShare, username: mountUsername, password: secret)
        }.value
        return mountRoot.appendingPathComponent(selectedEntry.path)
    }

    func disconnect() {
        let oldManager = manager
        manager = nil
        isConnected = false
        entries = []
        selectedPath = nil
        status = "已断开目录浏览连接；已挂载的共享仍可供转录使用。"
        Task { try? await oldManager?.disconnectShare(gracefully: true) }
    }

    private func loadDirectory() async throws {
        guard let manager else { return }
        let attributes = try await manager.contentsOfDirectory(atPath: currentPath)
        entries = attributes.compactMap { item in
            guard let name = item[.nameKey] as? String else { return nil }
            let isDirectory = (item[.isDirectoryKey] as? NSNumber)?.boolValue
                ?? ((item[.fileResourceTypeKey] as? URLFileResourceType) == .directory)
            let size = (item[.fileSizeKey] as? NSNumber)?.int64Value ?? 0
            let modified = item[.contentModificationDateKey] as? Date ?? .distantPast
            let path = currentPath.isEmpty ? name : "\(currentPath)/\(name)"
            return SMBEntry(path: path, name: name, isDirectory: isDirectory, size: size, modifiedAt: modified)
        }
        selectedPath = nil
        status = "已读取 \(entries.count) 项；列表仅显示文件夹和视频。"
    }

    private func keychainAccount(endpoint: SMBEndpoint, share: String) -> String {
        "\(endpoint.hostLabel)|\(share)|\(domain)|\(username)"
    }

    private func saveNonSecretSettings() {
        defaults.set(server, forKey: "smb.server")
        defaults.set(share, forKey: "smb.share")
        defaults.set(domain, forKey: "smb.domain")
        defaults.set(username, forKey: "smb.username")
    }
}

private func mountSMBShare(serverURL: URL, share: String, username: String, password: String) throws -> URL {
    let shareURL = serverURL.appendingPathComponent(share)
    if let mounted = existingMountedSMBShare(for: shareURL, username: username) {
        return mounted
    }

    var mountpoints: Unmanaged<CFArray>?
    let result = NetFSMountURLSync(
        shareURL as CFURL,
        nil,
        username as CFString,
        password as CFString,
        nil,
        nil,
        &mountpoints
    )
    if result == 0,
       let paths = mountpoints?.takeRetainedValue() as? [String],
       let first = paths.first {
        return URL(fileURLWithPath: first, isDirectory: true)
    }

    // A mount can appear under a DNS-SD service alias rather than the resolved host name.
    if let mounted = existingMountedSMBShare(for: shareURL, username: username) {
        return mounted
    }
    throw SMBInputError.mountFailed(result)
}

private func existingMountedSMBShare(for shareURL: URL, username: String) -> URL? {
    let conventionalMount = URL(fileURLWithPath: "/Volumes", isDirectory: true)
        .appendingPathComponent(shareURL.lastPathComponent, isDirectory: true)
    if isSMBMount(conventionalMount) {
        return conventionalMount
    }

    let keys: [URLResourceKey] = [.volumeURLForRemountingKey]
    let requestedShare = shareURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    let requestedHost = normalizedSMBHost(shareURL.host ?? "")
    let requestedUser = username.trimmingCharacters(in: .whitespacesAndNewlines)

    let candidates: [(volume: URL, remount: URL)] = FileManager.default.mountedVolumeURLs(
        includingResourceValuesForKeys: keys,
        options: []
    )?.compactMap { volume in
        guard let remount = try? volume.resourceValues(forKeys: Set(keys)).volumeURLForRemounting,
              remount.scheme?.lowercased() == "smb",
              remount.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                .caseInsensitiveCompare(requestedShare) == .orderedSame else {
            return nil
        }
        return (volume, remount)
    } ?? []

    if let exactHost = candidates.first(where: {
        normalizedSMBHost($0.remount.host ?? "") == requestedHost
    }) {
        return exactHost.volume
    }

    // DNS-SD can expose `server.local` while macOS records
    // `server(SMB)._smb._tcp.local`. A unique share/user match is the same mount.
    let sameUser = candidates.filter {
        requestedUser.isEmpty
            || ($0.remount.user ?? "").caseInsensitiveCompare(requestedUser) == .orderedSame
    }
    return sameUser.count == 1 ? sameUser[0].volume : nil
}

private func isSMBMount(_ url: URL) -> Bool {
    var fileSystem = statfs()
    guard statfs(url.path, &fileSystem) == 0 else { return false }
    let type = withUnsafePointer(to: &fileSystem.f_fstypename) { pointer in
        pointer.withMemoryRebound(to: CChar.self, capacity: Int(MFSNAMELEN)) {
            String(cString: $0)
        }
    }
    return type == "smbfs"
}

private func normalizedSMBHost(_ value: String) -> String {
    var host = value.removingPercentEncoding?.lowercased() ?? value.lowercased()
    if let serviceRange = host.range(of: "._smb._tcp.") {
        host = String(host[..<serviceRange.lowerBound])
    }
    if host.hasSuffix(".local") { host.removeLast(".local".count) }
    for suffix in ["(smb)", " (smb)"] where host.hasSuffix(suffix) {
        host.removeLast(suffix.count)
    }
    return host.trimmingCharacters(in: CharacterSet(charactersIn: "."))
}

struct SMBBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = SMBBrowserModel()
    @State private var selectionError: String?
    let onChoose: (URL) -> Void

    var body: some View {
        VStack(spacing: 16) {
            header
            connectionForm
            Divider()
            browserToolbar
            fileList
            footer
        }
        .padding(22)
        .frame(minWidth: 900, minHeight: 650)
        .preferredColorScheme(.dark)
        .onAppear { model.startDiscovery() }
        .onDisappear { model.stopDiscovery() }
        .alert("SMB 文件不可用", isPresented: Binding(
            get: { selectionError != nil },
            set: { if !$0 { selectionError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(selectionError ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("快速浏览 SMB 视频").font(.title2.weight(.semibold))
                Text("直接用 SMB2/3 批量读取目录；选中文件后才交给 macOS 挂载供 FFmpeg 使用。")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("关闭") { dismiss() }
        }
    }

    private var connectionForm: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Label("局域网 SMB", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if model.discoveredServers.isEmpty {
                    Text(model.isDiscovering ? "正在搜索…" : "未发现设备")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.discoveredServers) { item in
                                Button {
                                    model.useDiscoveredServer(item)
                                } label: {
                                    Label(item.serviceName, systemImage: "externaldrive.connected.to.line.below")
                                }
                                .buttonStyle(.bordered)
                                .help(item.address)
                            }
                        }
                    }
                }
                Spacer()
                Button {
                    model.startDiscovery()
                } label: {
                    Label("重新扫描", systemImage: "arrow.clockwise")
                }
                .controlSize(.small)
            }
            HStack {
                TextField("服务器，例如 192.168.1.10", text: $model.server)
                TextField("共享名称", text: $model.share)
                TextField("域（可选）", text: $model.domain)
                    .frame(maxWidth: 150)
            }
            HStack {
                TextField("用户名", text: $model.username)
                SecureField("密码（仅存钥匙串）", text: $model.password)
                Toggle("记住密码", isOn: $model.rememberPassword)
                    .toggleStyle(.checkbox)
                if model.isConnected {
                    Button("断开", role: .destructive) { model.disconnect() }
                } else {
                    Button("连接") { model.connect() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .disabled(model.isBusy)
    }

    private var browserToolbar: some View {
        HStack(spacing: 10) {
            Button { model.goUp() } label: { Image(systemName: "chevron.left") }
                .disabled(!model.isConnected || model.currentPath.isEmpty || model.isBusy)
            Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
                .disabled(!model.isConnected || model.isBusy)
            Text(model.breadcrumb)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            TextField("搜索当前目录", text: $model.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
            Picker("排序", selection: $model.sortOrder) {
                ForEach(SMBSortOrder.allCases) { order in Text(order.title).tag(order) }
            }
            .frame(width: 190)
        }
    }

    private var fileList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("名称").frame(maxWidth: .infinity, alignment: .leading)
                Text("修改时间").frame(width: 170, alignment: .leading)
                Text("大小").frame(width: 100, alignment: .trailing)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            Divider()

            if model.isBusy {
                Spacer()
                ProgressView("正在读取目录…")
                Spacer()
            } else if !model.isConnected {
                Spacer()
                ContentUnavailableView("尚未连接", systemImage: "externaldrive.connected.to.line.below", description: Text("连接后会一次读取目录并在本机排序。"))
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(model.visibleEntries) { entry in
                            smbRow(entry)
                        }
                    }
                    .padding(5)
                }
            }
        }
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.10)))
    }

    private func smbRow(_ entry: SMBEntry) -> some View {
        HStack {
            Label(entry.name, systemImage: entry.isDirectory ? "folder.fill" : "film")
                .foregroundStyle(entry.isDirectory ? .cyan : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.modifiedAt == .distantPast ? "—" : entry.modifiedAt.formatted(date: .numeric, time: .shortened))
                .frame(width: 170, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(entry.isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(model.selectedPath == entry.path ? appAccent.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .contentShape(Rectangle())
        .onTapGesture { model.selectedPath = entry.path }
        .onTapGesture(count: 2) {
            if entry.isDirectory { model.open(entry) }
        }
    }

    private var footer: some View {
        HStack {
            if model.isBusy { ProgressView().controlSize(.small) }
            Text(model.status).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("打开文件夹") {
                if let entry = model.selectedEntry { model.open(entry) }
            }
            .disabled(model.selectedEntry?.isDirectory != true || model.isBusy)
            Button("选择此视频") { chooseSelectedVideo() }
                .buttonStyle(.borderedProminent)
                .disabled(model.selectedEntry?.isVideo != true || model.isBusy)
        }
    }

    private func chooseSelectedVideo() {
        model.isBusy = true
        Task {
            do {
                let url = try await model.mountedURLForSelection()
                onChoose(url)
                dismiss()
            } catch {
                selectionError = error.localizedDescription
            }
            model.isBusy = false
        }
    }
}
