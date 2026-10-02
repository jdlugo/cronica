import Foundation

/// Localized marketing headlines for App Store screenshots.
///
/// These are test-only — not shipped in the app bundle.
/// Each screen has an English headline plus translations for all 14 supported locales.
///
/// Headlines use `**text**` markup for accent-colored keywords.
/// The view renders `**` words in gold bold, the rest in white medium weight.
enum MarketingHeadlines {
    static let acquisitionScreenOrder = ["HomeScreen", "DetailScreen", "WatchlistScreen"]

    /// Returns the headline for a given screen and locale, falling back to English.
    static func headline(for screen: String, locale: String) -> String {
        let table = headlines[screen] ?? [:]
        return table[locale] ?? table["en-US"] ?? screen
    }

    // MARK: - Headline Tables

    private static let headlines: [String: [String: String]] = [
        "HomeScreen": homeScreen,
        "ExploreScreen": exploreScreen,
        "WatchlistScreen": watchlistScreen,
        "SearchScreen": searchScreen,
        "DetailScreen": detailScreen,
        "DetailCastScreen": detailCastScreen,
        "DetailTrailersScreen": detailTrailersScreen,
    ]

    // MARK: - Per-Screen Dictionaries

    private static let homeScreen: [String: String] = [
        "en-US": "**A New Movie** to Guess Every Day",
        "de":    "**Verpasse nie** was kommt",
        "es":    "**Una peli nueva** para adivinar cada día",
        "es-MX": "**Una peli nueva** para adivinar cada día",
        "fr":    "**Un nouveau film** à deviner chaque jour",
        "it":    "**Non perderti** le novità",
        "ja":    "**見逃さない** 次の作品を",
        "ko":    "**놓치지 마세요** 다음 작품을",
        "nl":    "**Mis nooit** wat er komt",
        "pl":    "**Nie przegap** nowości",
        "pt-BR": "**Um filme novo** para adivinhar todo dia",
        "sq":    "**Mos humbisni** asgjë",
        "tr":    "**Hiçbir şeyi** kaçırmayın",
        "zh":    "**精彩内容** 不容错过",
        "ar":    "**لا تفوّت** ما هو قادم",
    ]

    private static let exploreScreen: [String: String] = [
        "en-US": "**Explore** What Everyone's Watching",
        "de":    "**Entdecke** deinen nächsten Favoriten",
        "es":    "**Descubre** tu próximo favorito",
        "es-MX": "**Descubre** tu próximo favorito",
        "fr":    "**Trouvez** votre prochain coup de cœur",
        "it":    "**Scopri** il tuo prossimo preferito",
        "ja":    "**見つけよう** 次のお気に入りを",
        "ko":    "**발견하세요** 다음 최애를",
        "nl":    "**Ontdek** je volgende favoriet",
        "pl":    "**Odkryj** swój następny ulubiony tytuł",
        "pt-BR": "**Descubra** seu próximo favorito",
        "sq":    "**Zbuloni** favoritin tuaj të radhës",
        "tr":    "**Keşfedin** bir sonraki favorinizi",
        "zh":    "**发现** 你的下一个最爱",
        "ar":    "**اكتشف** المفضّل التالي لديك",
    ]

    private static let watchlistScreen: [String: String] = [
        "en-US": "**Save It Now.** Watch It Later.",
        "de":    "**Deine Watchlist** dein Stil",
        "es":    "**Guárdala hoy.** Mírala después.",
        "es-MX": "**Guárdala hoy.** Vela después.",
        "fr":    "**Gardez-le.** Regardez-le plus tard.",
        "it":    "**La tua lista** a modo tuo",
        "ja":    "**ウォッチリスト** あなただけの",
        "ko":    "**나만의** 관심 목록",
        "nl":    "**Jouw watchlist** jouw manier",
        "pl":    "**Twoja lista** twoje zasady",
        "pt-BR": "**Salve agora.** Assista depois.",
        "sq":    "**Lista juaj** mënyra juaj",
        "tr":    "**Listeniz** sizin tarzınız",
        "zh":    "**你的片单** 你做主",
        "ar":    "**قائمتك** بأسلوبك",
    ]

    private static let searchScreen: [String: String] = [
        "en-US": "**Find It** in Seconds",
        "de":    "**Finde** jeden Film oder jede Serie",
        "es":    "**Busca** cualquier película o serie",
        "es-MX": "**Busca** cualquier película o serie",
        "fr":    "**Trouvez** n'importe quel film ou série",
        "it":    "**Trova** qualsiasi film o serie",
        "ja":    "**検索** 映画もドラマもすぐ",
        "ko":    "**검색하세요** 영화와 시리즈를",
        "nl":    "**Vind** elke film of serie",
        "pl":    "**Znajdź** dowolny film lub serial",
        "pt-BR": "**Encontre** qualquer filme ou série",
        "sq":    "**Gjeni** çdo film apo serial",
        "tr":    "**Bulun** herhangi bir film veya dizi",
        "zh":    "**搜索** 任意电影或剧集",
        "ar":    "**ابحث** عن أي فيلم أو مسلسل",
    ]

    private static let detailScreen: [String: String] = [
        "en-US": "**Solved It?** See Where to Stream",
        "de":    "**Alle Details** auf einen Blick",
        "es":    "**¿La adivinaste?** Mira dónde verla",
        "es-MX": "**¿La adivinaste?** Mira dónde verla",
        "fr":    "**Trouvé ?** Voyez où le regarder",
        "it":    "**Ogni dettaglio** a colpo d'occhio",
        "ja":    "**すべての情報** をひと目で",
        "ko":    "**모든 정보를** 한눈에",
        "nl":    "**Alle details** in één oogopslag",
        "pl":    "**Wszystkie szczegóły** na pierwszy rzut oka",
        "pt-BR": "**Acertou?** Veja onde assistir",
        "sq":    "**Çdo detaj** me një shikim",
        "tr":    "**Tüm detaylar** bir bakışta",
        "zh":    "**详细信息** 一目了然",
        "ar":    "**كل التفاصيل** بلمحة واحدة",
    ]

    private static let detailCastScreen: [String: String] = [
        "en-US": "**Meet the Stars** Behind the Story",
        "de":    "**Besetzung, Crew** & mehr",
        "es":    "**Reparto, equipo** y más",
        "es-MX": "**Reparto, equipo** y más",
        "fr":    "**Casting, équipe** et plus",
        "it":    "**Cast, troupe** e altro",
        "ja":    "**キャスト** スタッフ情報",
        "ko":    "**출연진** 제작진 등",
        "nl":    "**Cast, crew** & meer",
        "pl":    "**Obsada, ekipa** i więcej",
        "pt-BR": "**Elenco, equipe** e mais",
        "sq":    "**Aktorët, ekipi** & më shumë",
        "tr":    "**Oyuncular, ekip** ve daha fazlası",
        "zh":    "**演员、剧组** 及更多",
        "ar":    "**الممثلون والطاقم** والمزيد",
    ]

    private static let detailTrailersScreen: [String: String] = [
        "en-US": "**Preview** Before You Commit",
        "de":    "**Trailer** & Empfehlungen",
        "es":    "**Tráileres** y recomendaciones",
        "es-MX": "**Tráileres** y recomendaciones",
        "fr":    "**Bandes-annonces** et recommandations",
        "it":    "**Trailer** e raccomandazioni",
        "ja":    "**予告編** とおすすめ",
        "ko":    "**예고편** & 추천",
        "nl":    "**Trailers** & aanbevelingen",
        "pl":    "**Zwiastuny** i rekomendacje",
        "pt-BR": "**Trailers** e recomendações",
        "sq":    "**Trajlerë** dhe rekomandime",
        "tr":    "**Fragmanlar** ve öneriler",
        "zh":    "**预告片** 与推荐",
        "ar":    "**إعلانات ترويجية** وتوصيات",
    ]
}
