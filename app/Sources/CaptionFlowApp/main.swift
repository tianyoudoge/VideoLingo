import SwiftUI
import AppKit
import UniformTypeIdentifiers

let appAccent = Color(red: 0.42, green: 0.76, blue: 0.96)
let appWarmAccent = Color(red: 0.96, green: 0.68, blue: 0.28)

@main
struct CaptionFlowApp: App {
    @StateObject private var job = JobModel()
    @StateObject private var dependencies = DependencyManager()
    @StateObject private var modelSettings = ModelSettings()
    @StateObject private var appSettings = AppSettings()
    @State private var isShowingModelSettings = false

    var body: some Scene {
        WindowGroup {
            ContentView(
                job: job,
                dependencies: dependencies,
                modelSettings: modelSettings,
                appSettings: appSettings,
                isShowingModelSettings: $isShowingModelSettings
            )
                .frame(minWidth: 1120, minHeight: 760)
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            CommandMenu(t("appMenu", appSettings.appLanguage)) {
                Button(t("modelManagement", appSettings.appLanguage)) {
                    isShowingModelSettings = true
                }
                .keyboardShortcut(",", modifiers: [.command])
            }

            CommandMenu(t("languageMenu", appSettings.appLanguage)) {
                Picker(t("appLanguage", appSettings.appLanguage), selection: $appSettings.appLanguage) {
                    ForEach(appLanguages, id: \.code) { language in
                        Text(languageName(language.code, appSettings.appLanguage, includeAuto: false)).tag(language.code)
                    }
                }
                Divider()
                Picker(t("sourceLanguage", appSettings.appLanguage), selection: $job.sourceLanguage) {
                    ForEach(sourceLanguages, id: \.code) { language in
                        Text(languageName(language.code, appSettings.appLanguage, includeAuto: true)).tag(language.code)
                    }
                }
                Picker(t("targetLanguage", appSettings.appLanguage), selection: $job.targetLanguage) {
                    ForEach(targetLanguages, id: \.code) { language in
                        Text(languageName(language.code, appSettings.appLanguage, includeAuto: false)).tag(language.code)
                    }
                }
            }

            CommandMenu(t("models", appSettings.appLanguage)) {
                Button(t("llmSettings", appSettings.appLanguage)) {
                    isShowingModelSettings = true
                }
                Divider()
                Picker(t("llmProvider", appSettings.appLanguage), selection: $modelSettings.providerID) {
                    ForEach(modelProviders) { provider in
                        Text(provider.name).tag(provider.id)
                    }
                }
                .onChange(of: modelSettings.providerID) { _, id in
                    if let provider = modelProviders.first(where: { $0.id == id }) {
                        modelSettings.apply(provider)
                    }
                }
                Divider()
                Button(t("whisperRuntime", appSettings.appLanguage)) {
                    dependencies.refresh()
                }
            }
        }
    }
}

struct BackendEvent: Decodable {
    let event: String
    let stage: String?
    let message: String?
    let percent: Double?
    let path: String?
    let index: Int?
    let start: Double?
    let end: Double?
    let source: String?
    let target: String?
    let durationSeconds: Double?
    let segmentCount: Int?
    let segmentIndex: Int?
    let provider: String?
    let model: String?
    let promptTokens: Int?
    let cachedPromptTokens: Int?
    let uncachedPromptTokens: Int?
    let completionTokens: Int?
    let totalTokens: Int?
}

struct SubtitleLine: Identifiable, Equatable {
    let id: Int
    var start: Double
    var end: Double
    var source: String
    var target: String
}

struct ModelProvider: Identifiable, Hashable {
    let id: String
    let name: String
    let baseURL: String
    let models: [String]
    let isCustom: Bool

    var defaultModel: String {
        models.first ?? ""
    }
}

struct LanguageChoice: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
}

let modelProviders: [ModelProvider] = [
    ModelProvider(id: "deepseek", name: "DeepSeek", baseURL: "https://api.deepseek.com/chat/completions", models: ["deepseek-v4-flash", "deepseek-chat", "deepseek-reasoner"], isCustom: false),
    ModelProvider(id: "doubao", name: "豆包", baseURL: "https://ark.cn-beijing.volces.com/api/v3/chat/completions", models: ["doubao-seed-1-6-flash-250715", "doubao-seed-1-6-250615", "doubao-seed-1-6-thinking-250715"], isCustom: false),
    ModelProvider(id: "bailian", name: "百炼 Qwen", baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions", models: ["qwen3-max", "qwen3-plus", "qwen3-turbo"], isCustom: false),
    ModelProvider(id: "kimi", name: "Kimi", baseURL: "https://api.moonshot.ai/v1/chat/completions", models: ["kimi-k2-turbo-preview", "moonshot-v1-32k", "moonshot-v1-128k"], isCustom: false),
    ModelProvider(id: "zhipu", name: "智谱", baseURL: "https://open.bigmodel.cn/api/paas/v4/chat/completions", models: ["glm-4.5-flash", "glm-4.5", "glm-4-flash"], isCustom: false),
    ModelProvider(id: "minimax", name: "MiniMax", baseURL: "https://api.minimax.io/v1/chat/completions", models: ["MiniMax-M1", "MiniMax-Text-01"], isCustom: false),
    ModelProvider(id: "custom", name: "Custom", baseURL: "", models: [""], isCustom: true)
]

let sourceLanguages: [LanguageChoice] = [
    LanguageChoice(code: "auto", name: "Auto Detect"),
    LanguageChoice(code: "en", name: "English"),
    LanguageChoice(code: "ja", name: "Japanese"),
    LanguageChoice(code: "zh", name: "Chinese"),
    LanguageChoice(code: "fr", name: "French"),
    LanguageChoice(code: "es", name: "Spanish"),
    LanguageChoice(code: "ko", name: "Korean"),
    LanguageChoice(code: "de", name: "German"),
    LanguageChoice(code: "it", name: "Italian"),
    LanguageChoice(code: "ru", name: "Russian"),
    LanguageChoice(code: "pt", name: "Portuguese"),
    LanguageChoice(code: "th", name: "Thai"),
    LanguageChoice(code: "vi", name: "Vietnamese")
]

let targetLanguages: [LanguageChoice] = [
    LanguageChoice(code: "en", name: "English"),
    LanguageChoice(code: "ja", name: "Japanese"),
    LanguageChoice(code: "zh-Hans", name: "简体中文"),
    LanguageChoice(code: "zh-Hant", name: "繁體中文"),
    LanguageChoice(code: "fr", name: "French"),
    LanguageChoice(code: "es", name: "Spanish")
]

let appLanguages: [LanguageChoice] = [
    LanguageChoice(code: "en", name: "English"),
    LanguageChoice(code: "ja", name: "Japanese"),
    LanguageChoice(code: "zh-Hans", name: "简体中文"),
    LanguageChoice(code: "zh-Hant", name: "繁體中文"),
    LanguageChoice(code: "fr", name: "French"),
    LanguageChoice(code: "es", name: "Spanish")
]

@MainActor
final class AppSettings: ObservableObject {
    @Published var appLanguage: String {
        didSet { UserDefaults.standard.set(appLanguage, forKey: "appLanguage") }
    }

    init() {
        appLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? detectSystemAppLanguage()
    }
}

func detectSystemAppLanguage() -> String {
    let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
    if preferred.contains("zh-hant") || preferred.contains("tw") || preferred.contains("hk") { return "zh-Hant" }
    if preferred.hasPrefix("zh") { return "zh-Hans" }
    if preferred.hasPrefix("ja") { return "ja" }
    if preferred.hasPrefix("fr") { return "fr" }
    if preferred.hasPrefix("es") { return "es" }
    if preferred.hasPrefix("en") { return "en" }
    return "en"
}

func t(_ key: String, _ language: String) -> String {
    let table: [String: [String: String]] = [
        "subtitle": [
            "en": "Video subtitle recognition and multilingual translation",
            "ja": "動画字幕認識と多言語翻訳",
            "zh-Hans": "视频字幕识别与多语言翻译",
            "zh-Hant": "影片字幕辨識與多語翻譯",
            "fr": "Reconnaissance de sous-titres vidéo et traduction multilingue",
            "es": "Reconocimiento de subtítulos de video y traducción multilingüe"
        ],
        "models": ["en": "Models", "ja": "モデル", "zh-Hans": "模型", "zh-Hant": "模型", "fr": "Modèles", "es": "Modelos"],
        "appMenu": ["en": "CaptionFlow", "ja": "CaptionFlow", "zh-Hans": "CaptionFlow", "zh-Hant": "CaptionFlow", "fr": "CaptionFlow", "es": "CaptionFlow"],
        "languageMenu": ["en": "Languages", "ja": "言語", "zh-Hans": "语言", "zh-Hant": "語言", "fr": "Langues", "es": "Idiomas"],
        "appLanguage": ["en": "App Language", "ja": "アプリの言語", "zh-Hans": "界面语言", "zh-Hant": "介面語言", "fr": "Langue de l'app", "es": "Idioma de la app"],
        "modelManagement": ["en": "Model Management...", "ja": "モデル管理...", "zh-Hans": "模型管理...", "zh-Hant": "模型管理...", "fr": "Gestion des modèles...", "es": "Gestión de modelos..."],
        "modelManagementTitle": ["en": "Model Management", "ja": "モデル管理", "zh-Hans": "模型管理", "zh-Hant": "模型管理", "fr": "Gestion des modèles", "es": "Gestión de modelos"],
        "modelManagementSubtitle": ["en": "Configure LLM providers and usage", "ja": "LLM プロバイダーと使用量を設定", "zh-Hans": "配置大模型供应商与用量", "zh-Hant": "配置大模型供應商與用量", "fr": "Configurer les fournisseurs LLM et l'utilisation", "es": "Configura proveedores LLM y uso"],
        "llmSettings": ["en": "LLM Settings...", "ja": "LLM 設定...", "zh-Hans": "大模型设置...", "zh-Hant": "大模型設定...", "fr": "Réglages LLM...", "es": "Ajustes LLM..."],
        "llmProvider": ["en": "LLM Provider", "ja": "LLM プロバイダー", "zh-Hans": "大模型供应商", "zh-Hant": "大模型供應商", "fr": "Fournisseur LLM", "es": "Proveedor LLM"],
        "whisperRuntime": ["en": "Whisper Runtime", "ja": "Whisper ランタイム", "zh-Hans": "Whisper 运行组件", "zh-Hant": "Whisper 執行元件", "fr": "Runtime Whisper", "es": "Runtime Whisper"],
        "done": ["en": "Done", "ja": "完了", "zh-Hans": "完成", "zh-Hant": "完成", "fr": "Terminé", "es": "Listo"],
        "provider": ["en": "Provider", "ja": "プロバイダー", "zh-Hans": "供应商", "zh-Hant": "供應商", "fr": "Fournisseur", "es": "Proveedor"],
        "keyConfigured": ["en": "Key configured", "ja": "Key 設定済み", "zh-Hans": "已配置 Key", "zh-Hant": "已配置 Key", "fr": "Key configurée", "es": "Key configurada"],
        "configuration": ["en": "Configuration", "ja": "設定", "zh-Hans": "配置", "zh-Hant": "配置", "fr": "Configuration", "es": "Configuración"],
        "providerName": ["en": "Provider Name", "ja": "プロバイダー名", "zh-Hans": "供应商名称", "zh-Hant": "供應商名稱", "fr": "Nom du fournisseur", "es": "Nombre del proveedor"],
        "modelName": ["en": "Model", "ja": "モデル", "zh-Hans": "模型", "zh-Hant": "模型", "fr": "Modèle", "es": "Modelo"],
        "customProviderHint": ["en": "Known providers use fixed endpoints and selectable models. Use Custom for your own endpoint and model name.", "ja": "既知のプロバイダーは固定エンドポイントと選択式モデルを使用します。独自のエンドポイントとモデル名は Custom を使ってください。", "zh-Hans": "已知厂商使用固定 endpoint 和模型选择。只有 Custom 支持自定义 endpoint 和模型名。", "zh-Hant": "已知廠商使用固定 endpoint 和模型選擇。只有 Custom 支援自訂 endpoint 和模型名稱。", "fr": "Les fournisseurs connus utilisent des endpoints fixes et des modèles sélectionnables. Utilisez Custom pour votre endpoint et modèle.", "es": "Los proveedores conocidos usan endpoints fijos y modelos seleccionables. Usa Custom para endpoint y modelo propios."],
        "chooseVideo": ["en": "Choose Video", "ja": "動画を選択", "zh-Hans": "选择视频", "zh-Hant": "選擇影片", "fr": "Choisir une vidéo", "es": "Elegir video"],
        "start": ["en": "Start", "ja": "開始", "zh-Hans": "开始生成", "zh-Hant": "開始產生", "fr": "Démarrer", "es": "Iniciar"],
        "stop": ["en": "Stop", "ja": "停止", "zh-Hans": "停止", "zh-Hant": "停止", "fr": "Arrêter", "es": "Detener"],
        "input": ["en": "Input", "ja": "入力", "zh-Hans": "输入", "zh-Hant": "輸入", "fr": "Entrée", "es": "Entrada"],
        "drag": ["en": "Drag video here", "ja": "動画をドラッグ", "zh-Hans": "可拖入视频", "zh-Hant": "可拖入影片", "fr": "Glissez une vidéo", "es": "Arrastra un video"],
        "subtitles": ["en": "Subtitles", "ja": "字幕", "zh-Hans": "字幕提取", "zh-Hant": "字幕擷取", "fr": "Sous-titres", "es": "Subtítulos"],
        "subtitleColumns": [
            "en": "Time / Source subtitle / Target subtitle",
            "ja": "時間 / 元字幕 / 翻訳字幕",
            "zh-Hans": "时间 / 源语言字幕 / 目标语言字幕",
            "zh-Hant": "時間 / 來源字幕 / 目標字幕",
            "fr": "Temps / Sous-titre source / Sous-titre cible",
            "es": "Tiempo / Subtítulo origen / Subtítulo destino"
        ],
        "sourceLanguage": ["en": "Source Language", "ja": "元言語", "zh-Hans": "源语言", "zh-Hant": "來源語言", "fr": "Langue source", "es": "Idioma origen"],
        "targetLanguage": ["en": "Target Language", "ja": "翻訳先言語", "zh-Hans": "目标语言", "zh-Hant": "目標語言", "fr": "Langue cible", "es": "Idioma destino"],
        "targetSubtitle": ["en": "Target Subtitle", "ja": "翻訳字幕", "zh-Hans": "目标字幕", "zh-Hant": "目標字幕", "fr": "Sous-titre cible", "es": "Subtítulo destino"],
        "video": ["en": "Video", "ja": "動画", "zh-Hans": "视频", "zh-Hant": "影片", "fr": "Vidéo", "es": "Video"],
        "outputDirectory": ["en": "Output Folder", "ja": "出力フォルダ", "zh-Hans": "输出目录", "zh-Hant": "輸出目錄", "fr": "Dossier de sortie", "es": "Carpeta de salida"],
        "defaultOutputDirectory": ["en": "Same as video", "ja": "動画と同じ", "zh-Hans": "默认视频所在目录", "zh-Hant": "預設影片所在目錄", "fr": "Même dossier que la vidéo", "es": "Misma carpeta del video"],
        "translationModel": ["en": "Translation Model", "ja": "翻訳モデル", "zh-Hans": "翻译模型", "zh-Hant": "翻譯模型", "fr": "Modèle de traduction", "es": "Modelo de traducción"],
        "components": ["en": "Components", "ja": "コンポーネント", "zh-Hans": "组件", "zh-Hant": "元件", "fr": "Composants", "es": "Componentes"],
        "installComponents": ["en": "Install Components", "ja": "コンポーネントをインストール", "zh-Hans": "安装组件", "zh-Hant": "安裝元件", "fr": "Installer les composants", "es": "Instalar componentes"]
    ]
    return table[key]?[language] ?? table[key]?["en"] ?? key
}

func languageName(_ code: String, _ appLanguage: String, includeAuto: Bool) -> String {
    let names: [String: [String: String]] = [
        "auto": ["en": "Auto Detect", "ja": "自動検出", "zh-Hans": "自动识别", "zh-Hant": "自動辨識", "fr": "Détection automatique", "es": "Detección automática"],
        "en": ["en": "English", "ja": "英語", "zh-Hans": "英语", "zh-Hant": "英語", "fr": "Anglais", "es": "Inglés"],
        "ja": ["en": "Japanese", "ja": "日本語", "zh-Hans": "日语", "zh-Hant": "日語", "fr": "Japonais", "es": "Japonés"],
        "zh": ["en": "Chinese", "ja": "中国語", "zh-Hans": "中文", "zh-Hant": "中文", "fr": "Chinois", "es": "Chino"],
        "zh-Hans": ["en": "Simplified Chinese", "ja": "簡体中国語", "zh-Hans": "简体中文", "zh-Hant": "簡體中文", "fr": "Chinois simplifié", "es": "Chino simplificado"],
        "zh-Hant": ["en": "Traditional Chinese", "ja": "繁体中国語", "zh-Hans": "繁体中文", "zh-Hant": "繁體中文", "fr": "Chinois traditionnel", "es": "Chino tradicional"],
        "fr": ["en": "French", "ja": "フランス語", "zh-Hans": "法语", "zh-Hant": "法語", "fr": "Français", "es": "Francés"],
        "es": ["en": "Spanish", "ja": "スペイン語", "zh-Hans": "西班牙语", "zh-Hant": "西班牙語", "fr": "Espagnol", "es": "Español"],
        "ko": ["en": "Korean", "ja": "韓国語", "zh-Hans": "韩语", "zh-Hant": "韓語", "fr": "Coréen", "es": "Coreano"],
        "de": ["en": "German", "ja": "ドイツ語", "zh-Hans": "德语", "zh-Hant": "德語", "fr": "Allemand", "es": "Alemán"],
        "it": ["en": "Italian", "ja": "イタリア語", "zh-Hans": "意大利语", "zh-Hant": "義大利語", "fr": "Italien", "es": "Italiano"],
        "ru": ["en": "Russian", "ja": "ロシア語", "zh-Hans": "俄语", "zh-Hant": "俄語", "fr": "Russe", "es": "Ruso"],
        "pt": ["en": "Portuguese", "ja": "ポルトガル語", "zh-Hans": "葡萄牙语", "zh-Hant": "葡萄牙語", "fr": "Portugais", "es": "Portugués"],
        "th": ["en": "Thai", "ja": "タイ語", "zh-Hans": "泰语", "zh-Hant": "泰語", "fr": "Thaï", "es": "Tailandés"],
        "vi": ["en": "Vietnamese", "ja": "ベトナム語", "zh-Hans": "越南语", "zh-Hant": "越南語", "fr": "Vietnamien", "es": "Vietnamita"]
    ]
    if !includeAuto && code == "auto" { return "" }
    return names[code]?[appLanguage] ?? names[code]?["en"] ?? code
}

@MainActor
final class ModelSettings: ObservableObject {
    @Published var providerID: String {
        didSet { save("providerID", providerID) }
    }
    @Published var providerName: String {
        didSet { save("providerName", providerName) }
    }
    @Published var baseURL: String {
        didSet { save("baseURL", baseURL) }
    }
    @Published var model: String {
        didSet {
            save("llmModel", model)
            save(Self.modelKey(providerID), model)
        }
    }
    @Published var apiKey: String {
        didSet { save(apiKeyKey(providerID), apiKey) }
    }

    init() {
        let defaults = UserDefaults.standard
        let storedProviderID = defaults.string(forKey: "providerID") ?? "deepseek"
        let provider = modelProviders.first(where: { $0.id == storedProviderID }) ?? modelProviders[0]
        providerID = storedProviderID
        providerName = defaults.string(forKey: "providerName") ?? provider.name
        baseURL = provider.isCustom ? (defaults.string(forKey: "baseURL") ?? "") : provider.baseURL
        model = defaults.string(forKey: Self.modelKey(storedProviderID)) ?? defaults.string(forKey: "llmModel") ?? provider.defaultModel
        apiKey = defaults.string(forKey: Self.apiKeyKey(storedProviderID)) ?? defaults.string(forKey: "apiKey") ?? ""
    }

    var displayName: String {
        "\(providerName) / \(model)"
    }

    func apply(_ provider: ModelProvider) {
        providerID = provider.id
        providerName = provider.name
        baseURL = provider.isCustom ? UserDefaults.standard.string(forKey: "baseURL") ?? "" : provider.baseURL
        model = UserDefaults.standard.string(forKey: Self.modelKey(provider.id)) ?? provider.defaultModel
        apiKey = UserDefaults.standard.string(forKey: Self.apiKeyKey(provider.id)) ?? ""
    }

    func hasAPIKey(_ provider: ModelProvider) -> Bool {
        !(UserDefaults.standard.string(forKey: Self.apiKeyKey(provider.id)) ?? "").isEmpty
    }

    func recordUsage(provider: String, model: String, prompt: Int, cachedPrompt: Int, completion: Int, total: Int) {
        guard prompt > 0 || completion > 0 || total > 0 else { return }
        let key = Self.statsKey(provider: provider, model: model)
        var stats = tokenStats(provider: provider, model: model)
        stats.promptTokens += max(0, prompt)
        stats.cachedPromptTokens += max(0, cachedPrompt)
        stats.completionTokens += max(0, completion)
        stats.totalTokens += max(0, total)
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: key)
        }
        objectWillChange.send()
    }

    func tokenStats(provider: String, model: String) -> TokenStats {
        let key = Self.statsKey(provider: provider, model: model)
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let stats = try? JSONDecoder().decode(TokenStats.self, from: data)
        else {
            return TokenStats()
        }
        return stats
    }

    private func save(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private static func apiKeyKey(_ providerID: String) -> String {
        "apiKey.\(providerID)"
    }

    private static func modelKey(_ providerID: String) -> String {
        "llmModel.\(providerID)"
    }

    private func apiKeyKey(_ providerID: String) -> String {
        Self.apiKeyKey(providerID)
    }

    private static func statsKey(provider: String, model: String) -> String {
        let raw = "\(provider).\(model)"
        let safe = raw.map { char in
            char.isLetter || char.isNumber || char == "-" || char == "_" ? char : "_"
        }
        return "tokenStats." + String(safe)
    }
}

struct TokenStats: Codable {
    var promptTokens = 0
    var cachedPromptTokens = 0
    var completionTokens = 0
    var totalTokens = 0

    var uncachedPromptTokens: Int {
        max(0, promptTokens - cachedPromptTokens)
    }
}

@MainActor
final class DependencyManager: ObservableObject {
    @Published var isInstalling = false
    @Published var status = "检查组件中"
    @Published var detail = ""

    private let modelURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small-q5_1.bin")!
    private let ffmpegURL = URL(string: "https://www.osxexperts.net/ffmpeg81arm.zip")!
    private let ffprobeURL = URL(string: "https://www.osxexperts.net/ffprobe81arm.zip")!

    var appSupportURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("CaptionFlow", isDirectory: true)
    }

    var legacyAppSupportURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("VideoLingo", isDirectory: true)
    }

    var toolsURL: URL {
        appSupportURL.appendingPathComponent("tools", isDirectory: true)
    }

    var modelsURL: URL {
        appSupportURL.appendingPathComponent("models", isDirectory: true)
    }

    var modelPath: String {
        let installed = modelsURL.appendingPathComponent("ggml-small-q5_1.bin").path
        if FileManager.default.fileExists(atPath: installed) {
            return installed
        }
        let legacy = legacyAppSupportURL.appendingPathComponent("models/ggml-small-q5_1.bin").path
        if FileManager.default.fileExists(atPath: legacy) {
            return legacy
        }
        let devMedium = defaultProjectRoot() + "/models/ggml-medium.bin"
        if FileManager.default.fileExists(atPath: devMedium) {
            return devMedium
        }
        return installed
    }

    var ffmpegPath: String {
        let installed = toolsURL.appendingPathComponent("ffmpeg").path
        if FileManager.default.fileExists(atPath: installed) {
            return installed
        }
        let legacy = legacyAppSupportURL.appendingPathComponent("tools/ffmpeg").path
        if FileManager.default.fileExists(atPath: legacy) {
            return legacy
        }
        return firstExistingPath(["/opt/homebrew/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/usr/bin/ffmpeg"]) ?? installed
    }

    var ffprobePath: String {
        let installed = toolsURL.appendingPathComponent("ffprobe").path
        if FileManager.default.fileExists(atPath: installed) {
            return installed
        }
        let legacy = legacyAppSupportURL.appendingPathComponent("tools/ffprobe").path
        if FileManager.default.fileExists(atPath: legacy) {
            return legacy
        }
        return firstExistingPath(["/opt/homebrew/bin/ffprobe", "/usr/local/bin/ffprobe", "/usr/bin/ffprobe"]) ?? installed
    }

    var isReady: Bool {
        FileManager.default.fileExists(atPath: modelPath)
            && FileManager.default.fileExists(atPath: ffmpegPath)
            && FileManager.default.fileExists(atPath: ffprobePath)
            && FileManager.default.fileExists(atPath: defaultBackendPath())
            && FileManager.default.fileExists(atPath: defaultWhisperBin())
    }

    var shortStatus: String {
        if isInstalling { return status }
        return isReady ? "组件已就绪" : "需要安装组件"
    }

    func refresh() {
        status = isReady ? "组件已就绪" : "需要安装组件"
        detail = isReady ? "模型、FFmpeg 和识别引擎都可用。" : "首次使用需要下载模型和音视频工具。"
    }

    func install() {
        guard !isInstalling else { return }
        isInstalling = true
        status = "准备安装组件"
        detail = "组件会下载到用户目录，不会写入系统目录。"

        Task {
            do {
                try await installComponents()
                status = "组件已就绪"
                detail = "可以开始处理视频。"
            } catch {
                status = "安装失败"
                detail = error.localizedDescription
            }
            isInstalling = false
        }
    }

    private func installComponents() async throws {
        try FileManager.default.createDirectory(at: toolsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: modelsURL, withIntermediateDirectories: true)

        let model = modelsURL.appendingPathComponent("ggml-small-q5_1.bin")
        if !FileManager.default.fileExists(atPath: model.path) {
            status = "下载识别模型"
            detail = "推荐模型约几十 MB，首次下载取决于网络。"
            try await download(modelURL, to: model)
        }

        if !FileManager.default.fileExists(atPath: toolsURL.appendingPathComponent("ffmpeg").path) {
            status = "下载 FFmpeg"
            detail = "用于从视频中提取音频。"
            try await downloadAndUnzip(ffmpegURL, executableName: "ffmpeg")
        }

        if !FileManager.default.fileExists(atPath: toolsURL.appendingPathComponent("ffprobe").path) {
            status = "下载 FFprobe"
            detail = "用于读取视频和音频时长。"
            try await downloadAndUnzip(ffprobeURL, executableName: "ffprobe")
        }
    }

    private func download(_ url: URL, to destination: URL) async throws {
        let (temporaryURL, _) = try await URLSession.shared.download(from: url)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
    }

    private func downloadAndUnzip(_ url: URL, executableName: String) async throws {
        let archive = appSupportURL.appendingPathComponent("\(executableName).zip")
        try await download(url, to: archive)
        try runTool("/usr/bin/unzip", ["-o", "-j", archive.path, "-d", toolsURL.path])

        let executable = toolsURL.appendingPathComponent(executableName)
        try runTool("/bin/chmod", ["+x", executable.path])
        try? runTool("/usr/bin/xattr", ["-cr", executable.path])
        try? runTool("/usr/bin/codesign", ["-s", "-", executable.path])
        try? FileManager.default.removeItem(at: archive)
    }
}

@MainActor
final class JobModel: ObservableObject {
    @Published var videoURL: URL?
    @Published var outputDir: URL?
    @Published var progress: Double = 0
    @Published var isRunning = false
    @Published var status = "等待视频"
    @Published var detail = "选择一个视频，生成目标语言外挂字幕。"
    @Published var outputSubtitle: String?
    @Published var durationSeconds: Double?
    @Published var segmentCount: Int?
    @Published var segmentIndex: Int?
    @Published var subtitles: [SubtitleLine] = []
    @Published var totalTokens = 0
    @Published var promptTokens = 0
    @Published var cachedPromptTokens = 0
    @Published var uncachedPromptTokens = 0
    @Published var completionTokens = 0

    @Published var sourceLanguage: String {
        didSet { UserDefaults.standard.set(sourceLanguage, forKey: "sourceLanguage") }
    }
    @Published var targetLanguage: String {
        didSet { UserDefaults.standard.set(targetLanguage, forKey: "targetLanguage") }
    }
    private let vadNoise: String = "-35dB"
    private let vadSilence: Double = 0.80
    private let maxSegment: Double = 240
    private let maxPackGap: Double = 8
    private var process: Process?
    private var lastPromptTokens = 0
    private var lastCachedPromptTokens = 0
    private var lastCompletionTokens = 0
    private var lastTotalTokens = 0
    private var usageRecorder: ((String, String, Int, Int, Int, Int) -> Void)?

    init() {
        sourceLanguage = UserDefaults.standard.string(forKey: "sourceLanguage") ?? "auto"
        targetLanguage = UserDefaults.standard.string(forKey: "targetLanguage") ?? "zh-Hans"
    }

    var videoName: String {
        videoURL?.lastPathComponent ?? "未选择视频"
    }

    var outputName: String {
        outputSubtitle.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "尚未生成"
    }

    var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    func chooseVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            setVideo(url)
        }
    }

    func setVideo(_ url: URL) {
        videoURL = url
        outputDir = url.deletingLastPathComponent()
        status = "已选择视频"
        detail = url.lastPathComponent
    }

    func chooseOutputDir() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            outputDir = panel.url
        }
    }

    func run(dependencies: DependencyManager, modelSettings: ModelSettings) {
        guard let videoURL else {
            status = "请选择视频"
            detail = "需要先选择一个视频文件。"
            return
        }
        guard dependencies.isReady else {
            status = "组件未安装"
            detail = "请先安装模型和音视频工具。"
            return
        }
        let resolvedOutputDir = outputDir ?? videoURL.deletingLastPathComponent()
        guard !modelSettings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status = "缺少模型 Key"
            detail = "请在模型管理里配置供应商和 API Key。"
            return
        }

        isRunning = true
        progress = 0
        outputSubtitle = nil
        durationSeconds = nil
        segmentCount = nil
        segmentIndex = nil
        subtitles = []
        totalTokens = 0
        promptTokens = 0
        cachedPromptTokens = 0
        uncachedPromptTokens = 0
        completionTokens = 0
        lastPromptTokens = 0
        lastCachedPromptTokens = 0
        lastCompletionTokens = 0
        lastTotalTokens = 0
        usageRecorder = { provider, model, prompt, cachedPrompt, completion, total in
            modelSettings.recordUsage(provider: provider, model: model, prompt: prompt, cachedPrompt: cachedPrompt, completion: completion, total: total)
        }
        status = "准备开始"
        detail = "正在启动本地识别后端。"

        let process = Process()
        self.process = process
        process.executableURL = URL(fileURLWithPath: defaultBackendPath())
        process.arguments = [
            "transcribe",
            "--input", videoURL.path,
            "--output-dir", resolvedOutputDir.path,
            "--api-key", modelSettings.apiKey,
            "--provider", modelSettings.providerName,
            "--base-url", modelSettings.baseURL,
            "--llm-model", modelSettings.model,
            "--model", dependencies.modelPath,
            "--whisper-bin", defaultWhisperBin(),
            "--ffmpeg", dependencies.ffmpegPath,
            "--ffprobe", dependencies.ffprobePath,
            "--language", sourceLanguage,
            "--target-language", targetLanguage,
            "--vad-noise", vadNoise,
            "--vad-silence", String(format: "%.2f", vadSilence),
            "--max-segment", String(format: "%.0f", maxSegment),
            "--max-pack-gap", String(format: "%.0f", maxPackGap)
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self?.handleOutput(text) }
        }
        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.status = "后端输出"
                self?.detail = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor in
                stdout.fileHandleForReading.readabilityHandler = nil
                stderr.fileHandleForReading.readabilityHandler = nil
                self?.isRunning = false
                if proc.terminationStatus != 0 {
                    self?.status = "任务失败"
                    self?.detail = "退出码 \(proc.terminationStatus)"
                }
            }
        }

        do {
            try process.run()
        } catch {
            isRunning = false
            status = "启动失败"
            detail = error.localizedDescription
        }
    }

    func cancel() {
        process?.terminate()
        isRunning = false
        status = "已停止"
        detail = "任务已取消。"
    }

    private func handleOutput(_ text: String) {
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let raw = String(line)
            guard let data = raw.data(using: .utf8),
                  let event = try? JSONDecoder().decode(BackendEvent.self, from: data) else {
                continue
            }
            apply(event)
        }
    }

    private func apply(_ event: BackendEvent) {
        if let percent = event.percent {
            progress = max(0, min(1, percent))
        }
        if let path = event.path, !path.isEmpty {
            outputSubtitle = path
        }
        if let duration = event.durationSeconds, duration > 0 {
            durationSeconds = duration
        }
        if let count = event.segmentCount, count > 0 {
            segmentCount = count
        }
        if let index = event.segmentIndex, index > 0 {
            segmentIndex = index
        }
        if let total = event.totalTokens, total > 0 {
            let prompt = event.promptTokens ?? promptTokens
            let cached = event.cachedPromptTokens ?? cachedPromptTokens
            let completion = event.completionTokens ?? completionTokens
            totalTokens = total
            promptTokens = prompt
            cachedPromptTokens = cached
            uncachedPromptTokens = event.uncachedPromptTokens ?? max(0, prompt - cached)
            completionTokens = completion

            let provider = event.provider ?? ""
            let model = event.model ?? ""
            let deltaPrompt = max(0, prompt - lastPromptTokens)
            let deltaCached = max(0, cached - lastCachedPromptTokens)
            let deltaCompletion = max(0, completion - lastCompletionTokens)
            let deltaTotal = max(0, total - lastTotalTokens)
            usageRecorder?(provider, model, deltaPrompt, deltaCached, deltaCompletion, deltaTotal)
            lastPromptTokens = prompt
            lastCachedPromptTokens = cached
            lastCompletionTokens = completion
            lastTotalTokens = total
        }

        switch event.event {
        case "subtitle":
            upsertSubtitle(event)
        case "done":
            status = "完成"
            detail = event.message ?? "中文字幕已生成。"
            progress = 1
        case "error":
            status = "出错"
            detail = event.message ?? "任务失败。"
        default:
            status = stageTitle(event.stage)
            detail = event.message ?? detail
        }
    }

    private func upsertSubtitle(_ event: BackendEvent) {
        guard let index = event.index else { return }
        let incoming = SubtitleLine(
            id: index,
            start: event.start ?? 0,
            end: event.end ?? 0,
            source: event.source ?? "",
            target: event.target ?? ""
        )
        if let existing = subtitles.firstIndex(where: { $0.id == index }) {
            if !incoming.source.isEmpty {
                subtitles[existing].source = incoming.source
            }
            if !incoming.target.isEmpty {
                subtitles[existing].target = incoming.target
            }
            subtitles[existing].start = incoming.start
            subtitles[existing].end = incoming.end
        } else {
            subtitles.append(incoming)
            subtitles.sort { $0.id < $1.id }
        }
        status = incoming.target.isEmpty ? "识别字幕" : "翻译字幕"
        detail = incoming.target.isEmpty ? "识别到第 \(index) 句源语言字幕。" : "翻译完成第 \(index) 句字幕。"
    }

    private func stageTitle(_ stage: String?) -> String {
        switch stage {
        case "extract": return "提取音频"
        case "vad": return "分析语音"
        case "whisper": return "识别字幕"
        case "translate": return "翻译字幕"
        case "complete": return "完成"
        default: return "处理中"
        }
    }
}

struct ContentView: View {
    @ObservedObject var job: JobModel
    @ObservedObject var dependencies: DependencyManager
    @ObservedObject var modelSettings: ModelSettings
    @ObservedObject var appSettings: AppSettings
    @Binding var isShowingModelSettings: Bool
    @State private var isDropTargeted = false

    var body: some View {
        ZStack {
            AppBackdrop()
            VStack(spacing: 0) {
                topBar
                mainGrid
            }
            if isDropTargeted {
                DropOverlay()
            }
        }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: handleDrop)
        .preferredColorScheme(.dark)
        .onAppear {
            dependencies.refresh()
        }
        .sheet(isPresented: $isShowingModelSettings) {
            ModelSettingsView(settings: modelSettings, appLanguage: appSettings.appLanguage)
                .frame(width: 680, height: 640)
        }
    }

    private var topBar: some View {
        HStack(spacing: 18) {
            BrandIcon(size: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text("CaptionFlow")
                    .font(.system(size: 24, weight: .semibold))
                Text(t("subtitle", appSettings.appLanguage))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.64))
            }

            Spacer()

            Button {
                isShowingModelSettings = true
            } label: {
                Label(t("models", appSettings.appLanguage), systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)

            Button {
                job.chooseVideo()
            } label: {
                Label(t("chooseVideo", appSettings.appLanguage), systemImage: "film")
            }
            .buttonStyle(.bordered)

            if job.isRunning {
                Button(role: .destructive) {
                    job.cancel()
                } label: {
                    Label(t("stop", appSettings.appLanguage), systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    job.run(dependencies: dependencies, modelSettings: modelSettings)
                } label: {
                    Label(t("start", appSettings.appLanguage), systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!dependencies.isReady || modelSettings.apiKey.isEmpty)
            }
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 26)
    }

    private var mainGrid: some View {
        VStack(spacing: 24) {
            ProgressGlassCard(job: job)

            HStack(alignment: .top, spacing: 30) {
                leftPanel
                    .frame(width: 430)
                subtitlePanel
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 34)
    }

    private var leftPanel: some View {
        VStack(spacing: 24) {
            InputGlassCard(job: job, modelSettings: modelSettings, appLanguage: appSettings.appLanguage) {
                isShowingModelSettings = true
            }
            DependencyGlassCard(dependencies: dependencies, appLanguage: appSettings.appLanguage)
        }
    }

    private var subtitlePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("subtitles", appSettings.appLanguage))
                        .font(.title3.weight(.semibold))
                    Text(t("subtitleColumns", appSettings.appLanguage))
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer()
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if job.subtitles.isEmpty {
                            EmptySubtitleState()
                                .frame(maxWidth: .infinity, minHeight: 360)
                        } else {
                            ForEach(job.subtitles) { line in
                                SubtitleCard(line: line)
                                    .id(line.id)
                            }
                        }
                    }
                    .padding(14)
                }
                .onChange(of: job.subtitles.count) { _, _ in
                    if let last = job.subtitles.last?.id {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassPanel()
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            var droppedURL: URL?
            if let data = item as? Data {
                droppedURL = URL(dataRepresentation: data, relativeTo: nil)
            } else if let url = item as? URL {
                droppedURL = url
            } else if let url = item as? NSURL {
                droppedURL = url as URL
            }

            guard let droppedURL, isVideoFile(droppedURL) else { return }
            Task { @MainActor in
                job.setVideo(droppedURL)
            }
        }
        return true
    }
}

struct DependencyGlassCard: View {
    @ObservedObject var dependencies: DependencyManager
    let appLanguage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("components", appLanguage))
                        .font(.headline)
                    Text(dependencies.shortStatus)
                        .font(.callout)
                        .foregroundStyle(dependencies.isReady ? appAccent : appWarmAccent)
                }
                Spacer()
                Image(systemName: dependencies.isReady ? "checkmark.circle.fill" : "arrow.down.circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(dependencies.isReady ? appAccent : appWarmAccent)
            }

            Text(dependencies.detail)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.66))
                .fixedSize(horizontal: false, vertical: true)

            if dependencies.isInstalling {
                ProgressView()
                    .controlSize(.small)
            } else if !dependencies.isReady {
                Button {
                    dependencies.install()
                } label: {
                    Label(t("installComponents", appLanguage), systemImage: "arrow.down.to.line")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .glassPanel()
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            if dependencies.isReady {
                dependencies.refresh()
            } else if !dependencies.isInstalling {
                dependencies.install()
            }
        }
    }
}

struct ProgressGlassCard: View {
    @ObservedObject var job: JobModel

    var body: some View {
        HStack(alignment: .center, spacing: 26) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(job.progressPercent)%")
                    .font(.system(size: 54, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(appAccent)
            }
            .frame(width: 150, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                Text(job.status)
                    .font(.headline)
                Text(job.detail)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: job.progress)
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 24) {
                Metric(label: "音频", value: durationText)
                Metric(label: "分段", value: segmentText)
                Metric(label: "Token", value: job.totalTokens > 0 ? "\(job.totalTokens)" : "--")
                Metric(label: "缓存/非缓存", value: job.totalTokens > 0 ? "\(job.cachedPromptTokens)/\(job.uncachedPromptTokens)" : "--")
                Metric(label: "输入/输出", value: job.totalTokens > 0 ? "\(job.promptTokens)/\(job.completionTokens)" : "--")
            }
            .frame(width: 460, alignment: .leading)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
        .glassPanel()
    }

    private var iconName: String {
        if job.isRunning { return "waveform" }
        if job.progress >= 1 { return "checkmark.circle.fill" }
        return "sparkles"
    }

    private var durationText: String {
        guard let duration = job.durationSeconds else { return "--" }
        return String(format: "%.1f 分钟", duration / 60)
    }

    private var segmentText: String {
        guard let count = job.segmentCount else { return "--" }
        if let current = job.segmentIndex {
            return "\(current)/\(count)"
        }
        return "\(count)"
    }
}

struct ModelSettingsView: View {
    @ObservedObject var settings: ModelSettings
    let appLanguage: String
    @Environment(\.dismiss) private var dismiss

    private var selectedProvider: ModelProvider {
        modelProviders.first(where: { $0.id == settings.providerID }) ?? modelProviders[0]
    }

    var body: some View {
        ZStack {
            AppBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t("modelManagementTitle", appLanguage))
                                .font(.title2.weight(.semibold))
                            Text(t("modelManagementSubtitle", appLanguage))
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.64))
                        }
                        Spacer()
                        Button(t("done", appLanguage)) { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text(t("provider", appLanguage))
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(modelProviders) { provider in
                                Button {
                                    settings.apply(provider)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(provider.name)
                                                .font(.callout.weight(.semibold))
                                            Text(settings.hasAPIKey(provider) ? "\(provider.defaultModel) · \(t("keyConfigured", appLanguage))" : provider.defaultModel)
                                                .font(.caption)
                                                .foregroundStyle(.white.opacity(0.58))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if settings.providerID == provider.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(appAccent)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(settings.providerID == provider.id ? 0.14 : 0.07), in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(settings.hasAPIKey(provider) ? appAccent.opacity(0.46) : Color.white.opacity(0.06))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(18)
                    .glassPanel()

                    VStack(alignment: .leading, spacing: 12) {
                        Text(t("configuration", appLanguage))
                            .font(.headline)

                        if selectedProvider.isCustom {
                            TextField(t("providerName", appLanguage), text: $settings.providerName)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                            TextField("Base URL", text: $settings.baseURL)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                            TextField(t("modelName", appLanguage), text: $settings.model)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        } else {
                            Picker(t("modelName", appLanguage), selection: $settings.model) {
                                ForEach(selectedProvider.models, id: \.self) { model in
                                    Text(model).tag(model)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }

                        SecureField("API Key", text: $settings.apiKey)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(18)
                    .glassPanel()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Token Usage")
                            .font(.headline)
                        CurrentModelUsage(settings: settings)
                    }
                    .padding(18)
                    .glassPanel()

                    Text(t("customProviderHint", appLanguage))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.54))
                }
                .padding(24)
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct CurrentModelUsage: View {
    @ObservedObject var settings: ModelSettings

    var body: some View {
        let stats = settings.tokenStats(provider: settings.providerName, model: settings.model)
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.displayName)
                    .font(.caption.weight(.semibold))
                Text("prompt / cache hit / cache miss / output / total")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.50))
            }
            HStack(spacing: 16) {
                Text("\(stats.promptTokens)")
                Text("\(stats.cachedPromptTokens)")
                Text("\(stats.uncachedPromptTokens)")
                Text("\(stats.completionTokens)")
                Text("\(stats.totalTokens)")
            }
            .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.86))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InputGlassCard: View {
    @ObservedObject var job: JobModel
    @ObservedObject var modelSettings: ModelSettings
    let appLanguage: String
    let onModelTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(t("input", appLanguage))
                    .font(.headline)
                Spacer()
                Text(t("drag", appLanguage))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(appAccent)
            }

            VStack(alignment: .leading, spacing: 12) {
                Button {
                    job.chooseVideo()
                } label: {
                    CompactPath(title: t("video", appLanguage), value: job.videoName, icon: "film")
                }
                .buttonStyle(.plain)

                HStack {
                    Button {
                        job.chooseOutputDir()
                    } label: {
                        CompactPath(title: t("outputDirectory", appLanguage), value: job.outputDir?.path ?? t("defaultOutputDirectory", appLanguage), icon: "folder")
                    }
                    .buttonStyle(.plain)

                    Button {
                        job.chooseOutputDir()
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .buttonStyle(.bordered)
                    .help("选择输出目录")
                }

                Picker(t("sourceLanguage", appLanguage), selection: $job.sourceLanguage) {
                    ForEach(sourceLanguages, id: \.code) { language in
                        Text(languageName(language.code, appLanguage, includeAuto: true)).tag(language.code)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                Picker(t("targetLanguage", appLanguage), selection: $job.targetLanguage) {
                    ForEach(targetLanguages, id: \.code) { language in
                        Text(languageName(language.code, appLanguage, includeAuto: false)).tag(language.code)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    onModelTap()
                } label: {
                    CompactPath(title: t("translationModel", appLanguage), value: modelSettings.displayName, icon: "cpu")
                }
                .buttonStyle(.plain)

                Divider()
                    .opacity(0.45)

                CompactPath(title: t("targetSubtitle", appLanguage), value: job.outputName, icon: "captions.bubble")
                if let path = job.outputSubtitle {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(20)
        .glassPanel()
    }
}

struct OutputGlassCard: View {
    @ObservedObject var job: JobModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("输出")
                .font(.headline)
            CompactPath(title: "中文字幕", value: job.outputName, icon: "captions.bubble")
            if let path = job.outputSubtitle {
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .glassPanel()
    }
}

struct SubtitleCard: View {
    let line: SubtitleLine

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
                Text(timeRange)
                    .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.62))
                .frame(width: 96, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text(line.source.isEmpty ? "识别中..." : line.source)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                if line.target.isEmpty {
                    Text("翻译中...")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.50))
                } else {
                    Text(line.target)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.14))
        )
    }

    private var timeRange: String {
        "\(formatTime(line.start)) - \(formatTime(line.end))"
    }
}

struct EmptySubtitleState: View {
    var body: some View {
        VStack(spacing: 12) {
            BrandIcon(size: 72)
                .opacity(0.78)
            Text("字幕会在这里实时出现")
                .font(.headline)
            Text("只显示时间、源语言字幕和目标语言字幕。")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.58))
        }
    }
}

struct DropOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "film.stack.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(appAccent)
                Text("松开导入视频")
                    .font(.title2.weight(.semibold))
                Text("CaptionFlow 会使用视频所在目录作为默认输出目录")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.68))
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 34)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(appAccent.opacity(0.58), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.36), radius: 36, x: 0, y: 18)
        }
    }
}

struct BrandIcon: View {
    let size: CGFloat

    var body: some View {
        if let image = NSImage(named: "app-icon") ?? loadBrandImage() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
                .shadow(color: appAccent.opacity(0.24), radius: size * 0.20, x: 0, y: size * 0.08)
        } else {
            Image(systemName: "captions.bubble.fill")
                .font(.system(size: size * 0.62, weight: .semibold))
                .frame(width: size, height: size)
        }
    }
}

struct CompactPath: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(appAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct Metric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
    }
}

struct AppBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.055, green: 0.065, blue: 0.085),
                Color(red: 0.095, green: 0.115, blue: 0.145),
                Color(red: 0.155, green: 0.125, blue: 0.155)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

extension View {
    func glassPanel() -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: 16)
    }
}

func formatTime(_ seconds: Double) -> String {
    let clamped = max(0, seconds)
    let total = Int(clamped.rounded())
    let minute = total / 60
    let second = total % 60
    return String(format: "%02d:%02d", minute, second)
}

func loadBrandImage() -> NSImage? {
    if let url = Bundle.main.url(forResource: "app-icon", withExtension: "png") {
        return NSImage(contentsOf: url)
    }
    let projectURL = URL(fileURLWithPath: defaultProjectRoot())
        .appendingPathComponent("app/Assets/UI/app-icon.png")
    return NSImage(contentsOf: projectURL)
}

func isVideoFile(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    return ["mp4", "mov", "mkv", "avi", "m4v", "webm", "ts", "mts", "m2ts"].contains(ext)
}

func defaultBackendPath() -> String {
    let env = ProcessInfo.processInfo.environment["CAPTIONFLOW_BACKEND"]
        ?? ProcessInfo.processInfo.environment["VIDEOLINGO_BACKEND"]
        ?? ProcessInfo.processInfo.environment["MOVKNOWN_BACKEND"]
    if let env, !env.isEmpty { return env }
    if let bundled = Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent("captionflow-backend"),
       FileManager.default.fileExists(atPath: bundled.path) {
        return bundled.path
    }
    return defaultProjectRoot() + "/bin/captionflow-backend"
}

func defaultModelPath() -> String {
    let env = ProcessInfo.processInfo.environment["CAPTIONFLOW_WHISPER_MODEL"]
        ?? ProcessInfo.processInfo.environment["VIDEOLINGO_WHISPER_MODEL"]
        ?? ProcessInfo.processInfo.environment["MOVKNOWN_WHISPER_MODEL"]
    if let env, !env.isEmpty { return env }
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let appSupport = base.appendingPathComponent("CaptionFlow/models/ggml-small-q5_1.bin")
    if FileManager.default.fileExists(atPath: appSupport.path) {
        return appSupport.path
    }
    let legacy = base.appendingPathComponent("VideoLingo/models/ggml-small-q5_1.bin")
    if FileManager.default.fileExists(atPath: legacy.path) {
        return legacy.path
    }
    let medium = defaultProjectRoot() + "/models/ggml-medium.bin"
    if FileManager.default.fileExists(atPath: medium) {
        return medium
    }
    return appSupport.path
}

func defaultWhisperBin() -> String {
    let env = ProcessInfo.processInfo.environment["CAPTIONFLOW_WHISPER_BIN"]
        ?? ProcessInfo.processInfo.environment["VIDEOLINGO_WHISPER_BIN"]
        ?? ProcessInfo.processInfo.environment["MOVKNOWN_WHISPER_BIN"]
    if let env, !env.isEmpty { return env }
    if let bundled = Bundle.main.resourceURL?.appendingPathComponent("whisper/whisper-cli"),
       FileManager.default.fileExists(atPath: bundled.path) {
        return bundled.path
    }
    return defaultProjectRoot() + "/bin/whisper-cli"
}

func defaultProjectRoot() -> String {
    let bundleURL = Bundle.main.bundleURL
    if bundleURL.pathExtension == "app" {
        return bundleURL.deletingLastPathComponent().path
    }
    return FileManager.default.currentDirectoryPath
}

func firstExistingPath(_ paths: [String]) -> String? {
    paths.first { FileManager.default.fileExists(atPath: $0) }
}

func runTool(_ executable: String, _ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    let errorPipe = Pipe()
    process.standardError = errorPipe
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let message = String(data: data, encoding: .utf8) ?? executable
        throw NSError(domain: "CaptionFlow", code: Int(process.terminationStatus), userInfo: [
            NSLocalizedDescriptionKey: message.trimmingCharacters(in: .whitespacesAndNewlines)
        ])
    }
}
