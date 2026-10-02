#!/usr/bin/env python3
"""
Generate localized App Store metadata for fastlane deliver.

Creates fastlane/metadata/{locale}/ directories with localized:
  - name.txt (30 char limit)
  - subtitle.txt (30 char limit)
  - description.txt (4000 char limit)
  - keywords.txt (100 char limit)
  - promotional_text.txt (170 char limit)
  - release_notes.txt
  - support_url.txt, marketing_url.txt, privacy_url.txt

Usage:
    python3 scripts/generate_localized_metadata.py
    python3 scripts/generate_localized_metadata.py --dry-run
    python3 scripts/generate_localized_metadata.py --validate
"""

import argparse
import os

# ---------------------------------------------------------------------------
# App Store Connect locale codes
# ---------------------------------------------------------------------------
LOCALES = [
    "en-US", "ar-SA", "ca", "de-DE", "es-ES", "es-MX", "fr-FR", "it",
    "ja", "ko", "nl-NL", "pl", "pt-BR", "tr", "zh-Hans",
]

# ---------------------------------------------------------------------------
# URLs — same for all locales
# ---------------------------------------------------------------------------
SUPPORT_URL = "http://www.streamingnowapp.com/support/"
MARKETING_URL = "http://www.streamingnowapp.com/support/"
PRIVACY_URL = "http://www.streamingnowapp.com/privacy/"

# ---------------------------------------------------------------------------
# Release notes — update these each release
# ---------------------------------------------------------------------------
RELEASE_NOTES = {
    "en-US":   "• Refreshed Daily Puzzle with more reliable streak and progress tracking\n• Reduced disruptive full-screen ads\n• Updated for iOS 26 with stability and performance improvements",
    "ar-SA":   "• تحديث اللغز اليومي مع تتبع أكثر موثوقية للسلسلة والتقدم\n• تقليل الإعلانات المزعجة بملء الشاشة\n• تحديث لنظام iOS 26 مع تحسينات في الاستقرار والأداء",
    "ca":      "• Puzzle diari renovat amb un seguiment més fiable de ratxes i progrés\n• Menys anuncis molestos a pantalla completa\n• Actualitzat per a iOS 26 amb millores d'estabilitat i rendiment",
    "de-DE":   "• Überarbeitetes tägliches Rätsel mit zuverlässigerer Serien- und Fortschrittsanzeige\n• Weniger störende Vollbildanzeigen\n• Für iOS 26 aktualisiert, mit Stabilitäts- und Leistungsverbesserungen",
    "es-ES":   "• Puzzle diario renovado con un seguimiento más fiable de rachas y progreso\n• Menos anuncios molestos a pantalla completa\n• Actualizado para iOS 26 con mejoras de estabilidad y rendimiento",
    "es-MX":   "• Puzzle diario renovado con seguimiento más confiable de rachas y progreso\n• Menos anuncios molestos a pantalla completa\n• Actualizado para iOS 26 con mejoras de estabilidad y rendimiento",
    "fr-FR":   "• Puzzle quotidien repensé avec un suivi plus fiable des séries et de la progression\n• Moins de publicités plein écran gênantes\n• Mise à jour pour iOS 26 avec des améliorations de stabilité et de performances",
    "it":      "• Puzzle giornaliero rinnovato con un monitoraggio più affidabile di serie e progressi\n• Meno annunci invasivi a schermo intero\n• Aggiornato per iOS 26 con miglioramenti di stabilità e prestazioni",
    "ja":      "• デイリーパズルを刷新し、連続記録と進捗の追跡を改善\n• 全画面広告の表示頻度を削減\n• iOS 26に対応し、安定性とパフォーマンスを改善",
    "ko":      "• 일일 퍼즐을 새롭게 개선하고 연속 기록과 진행 상황 추적의 안정성을 향상\n• 방해가 되는 전체 화면 광고 감소\n• iOS 26 지원 및 안정성과 성능 개선",
    "nl-NL":   "• Vernieuwde dagelijkse puzzel met betrouwbaardere reeks- en voortgangsregistratie\n• Minder storende advertenties op volledig scherm\n• Bijgewerkt voor iOS 26 met stabiliteits- en prestatieverbeteringen",
    "pl":      "• Odświeżona codzienna zagadka z lepszym śledzeniem serii i postępów\n• Mniej uciążliwych reklam pełnoekranowych\n• Aktualizacja dla iOS 26 z poprawą stabilności i wydajności",
    "pt-BR":   "• Puzzle diário renovado com acompanhamento mais confiável de sequência e progresso\n• Menos anúncios inconvenientes em tela cheia\n• Atualizado para iOS 26 com melhorias de estabilidade e desempenho",
    "tr":      "• Günlük Bulmaca yenilendi; seri ve ilerleme takibi daha güvenilir\n• Rahatsız edici tam ekran reklamlar azaltıldı\n• iOS 26 için kararlılık ve performans iyileştirmeleri",
    "zh-Hans": "• 焕新每日谜题，连续记录和进度追踪更加可靠\n• 减少干扰性的全屏广告\n• 适配 iOS 26，并提升稳定性和性能",
}

# ---------------------------------------------------------------------------
# App name (30 char limit)
# Brand "Streaming Now" stays consistent; descriptor is localized.
# ---------------------------------------------------------------------------
NAME = {
    "en-US":   "Streaming Now: TV & Movies",
    "ar-SA":   "Streaming Now: أفلام ومسلسلات",
    "ca":      "Streaming Now: Sèries i films",
    "de-DE":   "Streaming Now: Filme & Serien",
    "es-ES":   "Streaming Now: Series y cine",
    "es-MX":   "Streaming Now: Series y cine",
    "fr-FR":   "Streaming Now : Films & séries",
    "it":      "Streaming Now: Film e serie",
    "ja":      "Streaming Now: 映画・ドラマ",
    "ko":      "Streaming Now: 영화·드라마",
    "nl-NL":   "Streaming Now: Films & series",
    "pl":      "Streaming Now: Filmy i seriale",
    "pt-BR":   "Streaming Now: Filmes e séries",
    "tr":      "Streaming Now: Dizi ve film",
    "zh-Hans": "Streaming Now: 影视追踪",
}

# ---------------------------------------------------------------------------
# Subtitle (30 char limit)
# Strategy: action verbs + high-value keywords, no overlap with title words.
# ---------------------------------------------------------------------------
SUBTITLE = {
    "en-US":   "Track Shows & Discover Movies",
    "ar-SA":   "تتبع المسلسلات واكتشف الأفلام",
    "ca":      "Sèries i pel·lícules al dia",
    "de-DE":   "Serien & Filme tracken",
    "es-ES":   "Rastrea series y descubre cine",
    "es-MX":   "Rastrea series y descubre cine",
    "fr-FR":   "Séries et films à portée",
    "it":      "Serie e film a portata di tap",
    "ja":      "ドラマ・映画を追跡＆発見",
    "ko":      "드라마·영화 추적 및 발견",
    "nl-NL":   "Series & films bijhouden",
    "pl":      "Śledź seriale, odkrywaj filmy",
    "pt-BR":   "Acompanhe séries e filmes",
    "tr":      "Dizileri takip et, film keşfet",
    "zh-Hans": "追剧看片 一站管理",
}

# ---------------------------------------------------------------------------
# Keywords (100 char limit)
# Rules: no spaces after commas, no overlap with title or subtitle words.
# Focus: high-intent search terms specific to each market.
# ---------------------------------------------------------------------------
KEYWORDS = {
    # Title words to avoid: streaming, now, netflix, guide
    # Subtitle words to avoid: track, shows, discover, movies
    "en-US":   "watchlist,episodes,series,film,upcoming,ratings,where,watch,hulu,disney,tv,binge,new,tracker,diary",
    "ar-SA":   "قائمة,حلقات,بث,مشاهدة,جديد,تقييم,ديزني,هولو,تلفزيون,سينما,مواسم,توصيات,أين,مفضلة",
    "ca":      "watchlist,episodis,sèries,estrenes,valoracions,on,veure,hulu,disney,tv,marató,nou,seguiment",
    "de-DE":   "watchlist,episoden,staffeln,bewertung,wo,schauen,hulu,disney,tv,binge,neu,vorschau,tagebuch",
    "es-ES":   "watchlist,episodios,temporadas,valoración,dónde,ver,hulu,disney,tv,maratón,nuevo,estreno,diario",
    "es-MX":   "watchlist,episodios,temporadas,valoración,dónde,ver,hulu,disney,tv,maratón,nuevo,estreno,diario",
    "fr-FR":   "watchlist,épisodes,saisons,note,où,regarder,hulu,disney,tv,binge,nouveau,sortie,agenda,suivi",
    "it":      "watchlist,episodi,stagioni,voto,dove,guardare,hulu,disney,tv,binge,nuovo,uscita,diario,lista",
    "ja":      "ウォッチリスト,エピソード,シーズン,評価,どこで,視聴,hulu,disney,ドラマ,新作,おすすめ,配信,予告編,通知,リスト,人気,韓国ドラマ,アニメ,映画館",
    "ko":      "시청목록,에피소드,시즌,평가,어디서,시청,hulu,disney,드라마,신작,추천,배급,목록,알림,예고편,인기,한국드라마,애니,왓챠,웨이브",
    "nl-NL":   "watchlist,afleveringen,seizoenen,beoordeling,waar,kijken,hulu,disney,tv,binge,nieuw,agenda,lijst",
    "pl":      "watchlist,odcinki,sezony,ocena,gdzie,oglądać,hulu,disney,tv,binge,nowy,premiera,lista,dziennik",
    "pt-BR":   "watchlist,episódios,temporadas,avaliação,onde,assistir,hulu,disney,tv,maratona,novo,estreia,lista",
    "tr":      "watchlist,bölümler,sezonlar,puan,nerede,izle,hulu,disney,tv,maraton,yeni,çıkış,liste,günlük",
    "zh-Hans": "片单,剧集,季度,评分,哪里,观看,hulu,disney,电视,追剧,新片,推荐,列表,日记,通知,预告片,热门,韩剧,美剧,动漫,评论,收藏",
}

# ---------------------------------------------------------------------------
# Promotional text (170 char limit) — updatable without app review
# ---------------------------------------------------------------------------
PROMOTIONAL_TEXT = {
    "en-US":   "Never miss what to watch next. Track movies and TV shows, get notified about new episodes, and find where to stream — all synced across your devices with iCloud.",
    "ar-SA":   "لا تفوّت ما ستشاهده بعد ذلك. تتبع الأفلام والمسلسلات، واحصل على إشعارات بالحلقات الجديدة، واعرف أين تشاهد — مع مزامنة iCloud عبر جميع أجهزتك.",
    "ca":      "No et perdis res. Fes seguiment de pel·lícules i sèries, rep notificacions de nous episodis i troba on mirar-ho — tot sincronitzat amb iCloud.",
    "de-DE":   "Verpasse nie, was als Nächstes kommt. Tracke Filme und Serien, erhalte Benachrichtigungen bei neuen Folgen und finde, wo du streamen kannst — per iCloud synchron.",
    "es-ES":   "No te pierdas nada. Rastrea películas y series, recibe avisos de nuevos episodios y encuentra dónde verlos — todo sincronizado con iCloud en todos tus dispositivos.",
    "es-MX":   "No te pierdas nada. Rastrea películas y series, recibe avisos de nuevos episodios y encuentra dónde verlos — todo sincronizado con iCloud en todos tus dispositivos.",
    "fr-FR":   "Ne manquez plus rien. Suivez films et séries, recevez des alertes pour les nouveaux épisodes et trouvez où regarder — synchronisé via iCloud sur tous vos appareils.",
    "it":      "Non perderti più nulla. Traccia film e serie, ricevi notifiche sui nuovi episodi e scopri dove guardare — tutto sincronizzato via iCloud su tutti i tuoi dispositivi.",
    "ja":      "次に何を観るか迷わない。映画やドラマを追跡し、新エピソードの通知を受け取り、どこで配信中か確認。iCloudですべてのデバイスに同期。",
    "ko":      "다음에 볼 작품을 놓치지 마세요. 영화와 드라마를 추적하고, 새 에피소드 알림을 받고, 어디서 볼 수 있는지 확인하세요. iCloud로 모든 기기에 동기화됩니다.",
    "nl-NL":   "Mis nooit meer wat je wilt kijken. Volg films en series, ontvang meldingen bij nieuwe afleveringen en ontdek waar je kunt kijken — alles gesynchroniseerd via iCloud.",
    "pl":      "Nie przegap tego, co warto obejrzeć. Śledź filmy i seriale, otrzymuj powiadomienia o nowych odcinkach i sprawdzaj, gdzie oglądać — wszystko zsynchronizowane przez iCloud.",
    "pt-BR":   "Nunca perca o que assistir. Acompanhe filmes e séries, receba alertas de novos episódios e descubra onde assistir — tudo sincronizado via iCloud nos seus dispositivos.",
    "tr":      "Sıradaki yapımı asla kaçırmayın. Film ve dizileri takip edin, yeni bölüm bildirimleri alın ve nerede izleyeceğinizi bulun — iCloud ile tüm cihazlarınızda senkronize.",
    "zh-Hans": "不再错过好片。追踪电影和电视剧，获取新剧集通知，查看哪里可以观看——通过 iCloud 在所有设备间同步。",
}

# ---------------------------------------------------------------------------
# Description (4000 char limit)
# Structure: hook paragraph → 4 feature sections with bullets → CTA
# ---------------------------------------------------------------------------
DESCRIPTION = {
    "en-US": """\
Never miss what to watch next. Streaming Now helps you discover movies and TV shows, track your watchlist, and get notified the moment new episodes and movies are released.

DISCOVER & EXPLORE
• Browse trending, popular, and upcoming titles updated daily
• Explore by genre with smart filters to match your mood
• Get personalized recommendations based on your taste
• Watch trailers and dive into cast, crew, and production details

YOUR WATCHLIST, YOUR WAY
• Build and organize watchlists with custom lists
• Mark movies and episodes as watched with one tap
• Rate and add personal notes to every title you watch
• Set notifications so you never miss a premiere or finale

FIND WHERE TO STREAM
• See which streaming services carry the movie or show you want
• Filter by your region for accurate availability
• Jump straight to the app and start watching

SYNC ACROSS ALL YOUR DEVICES
• iCloud keeps your watchlist in sync everywhere
• Apple Watch app for quick access on your wrist
• Home screen widgets to stay on top of what's next
• Available on iPhone, iPad, and Apple Watch

Download Streaming Now and never lose track of a show again.""",

    "ar-SA": """\
لا تفوّت ما ستشاهده بعد ذلك. يساعدك Streaming Now على اكتشاف الأفلام والمسلسلات وتتبع قائمة المشاهدة والحصول على إشعارات فورية عند صدور حلقات وأفلام جديدة.

اكتشف واستكشف
• تصفح العناوين الرائجة والشائعة والقادمة يومياً
• استكشف حسب التصنيف مع فلاتر ذكية تناسب مزاجك
• احصل على توصيات مخصصة بناءً على ذوقك
• شاهد الإعلانات واستعرض تفاصيل الممثلين وفريق العمل والإنتاج

قائمة المشاهدة كما تريدها
• أنشئ ونظم قوائم مشاهدة مخصصة
• حدد الأفلام والحلقات كمُشاهدة بنقرة واحدة
• قيّم وأضف ملاحظات شخصية لكل عنوان تشاهده
• اضبط الإشعارات حتى لا تفوتك أي عرض أول أو نهائي

اعرف أين تشاهد
• اطلع على خدمات البث التي تعرض الفيلم أو المسلسل الذي تريده
• فلتر حسب منطقتك لنتائج دقيقة
• انتقل مباشرة إلى التطبيق وابدأ المشاهدة

مزامنة عبر جميع أجهزتك
• iCloud يبقي قائمة مشاهدتك متزامنة في كل مكان
• تطبيق Apple Watch للوصول السريع من معصمك
• ودجات الشاشة الرئيسية لتبقى على اطلاع بما هو قادم
• متوفر على iPhone وiPad وApple Watch

حمّل Streaming Now ولا تفقد أثر أي مسلسل مرة أخرى.""",

    "ca": """\
No et perdis mai què veure. Streaming Now t'ajuda a descobrir pel·lícules i sèries, fer seguiment de la teva llista i rebre notificacions quan surten nous episodis i pel·lícules.

DESCOBREIX I EXPLORA
• Navega pels títols populars, tendència i pròxims, actualitzats diàriament
• Explora per gènere amb filtres intel·ligents segons el teu estat d'ànim
• Rep recomanacions personalitzades basades en els teus gustos
• Mira tràilers i descobreix detalls del repartiment i l'equip de producció

LA TEVA LLISTA, A LA TEVA MANERA
• Crea i organitza llistes personalitzades
• Marca pel·lícules i episodis com a vistos amb un sol toc
• Valora i afegeix notes personals a cada títol que vegis
• Configura notificacions per no perdre't cap estrena

TROBA ON MIRAR-HO
• Consulta quins serveis d'streaming tenen la pel·lícula o sèrie que vols
• Filtra per la teva regió per obtenir resultats precisos
• Accedeix directament a l'aplicació i comença a mirar

SINCRONITZA A TOTS ELS TEUS DISPOSITIUS
• iCloud manté la teva llista sincronitzada a tot arreu
• Aplicació per Apple Watch per accedir-hi ràpidament
• Widgets de pantalla d'inici per estar al dia
• Disponible a iPhone, iPad i Apple Watch

Descarrega Streaming Now i no perdis mai el fil de cap sèrie.""",

    "de-DE": """\
Verpasse nie, was als Nächstes kommt. Streaming Now hilft dir, Filme und Serien zu entdecken, deine Watchlist zu verwalten und sofort benachrichtigt zu werden, wenn neue Folgen und Filme erscheinen.

ENTDECKEN & ERKUNDEN
• Durchstöbere täglich aktualisierte Trends, beliebte und kommende Titel
• Erkunde nach Genre mit smarten Filtern passend zu deiner Stimmung
• Erhalte personalisierte Empfehlungen basierend auf deinem Geschmack
• Schau dir Trailer an und entdecke Details zu Cast, Crew und Produktion

DEINE WATCHLIST, DEIN STIL
• Erstelle und organisiere Watchlists mit eigenen Listen
• Markiere Filme und Episoden mit einem Tipp als gesehen
• Bewerte und füge persönliche Notizen zu jedem Titel hinzu
• Stelle Benachrichtigungen ein, damit du keine Premiere verpasst

FINDE HERAUS, WO DU STREAMEN KANNST
• Sieh, welche Streaming-Dienste den Film oder die Serie haben
• Filtere nach deiner Region für genaue Verfügbarkeit
• Spring direkt in die App und starte die Wiedergabe

AUF ALLEN GERÄTEN SYNCHRON
• iCloud hält deine Watchlist überall synchron
• Apple Watch App für schnellen Zugriff am Handgelenk
• Homescreen-Widgets, um immer auf dem Laufenden zu bleiben
• Verfügbar auf iPhone, iPad und Apple Watch

Lade Streaming Now herunter und verliere nie den Überblick.""",

    "es-ES": """\
No te pierdas nada. Streaming Now te ayuda a descubrir películas y series, gestionar tu lista de seguimiento y recibir notificaciones en el momento en que se estrenan nuevos episodios y películas.

DESCUBRE Y EXPLORA
• Explora títulos en tendencia, populares y próximos estrenos actualizados a diario
• Filtra por género con filtros inteligentes según tu estado de ánimo
• Recibe recomendaciones personalizadas basadas en tus gustos
• Mira tráileres y descubre detalles del reparto, equipo y producción

TU LISTA, A TU MANERA
• Crea y organiza listas de seguimiento personalizadas
• Marca películas y episodios como vistos con un solo toque
• Valora y añade notas personales a cada título que veas
• Configura notificaciones para no perderte ningún estreno

ENCUENTRA DÓNDE VER
• Consulta qué servicios de streaming tienen la película o serie que quieres
• Filtra por tu región para obtener resultados precisos
• Salta directamente a la app y empieza a ver

SINCRONIZADO EN TODOS TUS DISPOSITIVOS
• iCloud mantiene tu lista sincronizada en todas partes
• App de Apple Watch para acceso rápido desde tu muñeca
• Widgets en la pantalla de inicio para estar siempre al día
• Disponible en iPhone, iPad y Apple Watch

Descarga Streaming Now y no pierdas el hilo de ninguna serie.""",

    "es-MX": """\
No te pierdas nada. Streaming Now te ayuda a descubrir películas y series, llevar el control de tu lista y recibir notificaciones cuando se estrenan nuevos episodios y películas.

DESCUBRE Y EXPLORA
• Explora títulos en tendencia, populares y próximos estrenos actualizados diariamente
• Filtra por género con filtros inteligentes según tu ánimo
• Recibe recomendaciones personalizadas basadas en lo que te gusta
• Ve tráileres y descubre detalles del reparto, equipo y producción

TU LISTA, A TU MANERA
• Crea y organiza listas personalizadas de lo que quieres ver
• Marca películas y episodios como vistos con un solo toque
• Califica y agrega notas personales a cada título
• Configura notificaciones para no perderte ningún estreno ni final de temporada

ENCUENTRA DÓNDE VERLO
• Consulta qué plataformas de streaming tienen la película o serie que buscas
• Filtra por tu región para resultados precisos
• Ve directo a la app y empieza a ver

SINCRONIZADO EN TODOS TUS DISPOSITIVOS
• iCloud mantiene tu lista sincronizada en todos lados
• App de Apple Watch para acceso rápido desde tu muñeca
• Widgets en la pantalla de inicio para estar siempre al día
• Disponible en iPhone, iPad y Apple Watch

Descarga Streaming Now y nunca pierdas el hilo de una serie.""",

    "fr-FR": """\
Ne manquez plus jamais quoi regarder. Streaming Now vous aide à découvrir films et séries, gérer votre liste de visionnage et être notifié dès la sortie de nouveaux épisodes et films.

DÉCOUVRIR & EXPLORER
• Parcourez les titres tendance, populaires et à venir, mis à jour quotidiennement
• Explorez par genre avec des filtres intelligents selon votre humeur
• Recevez des recommandations personnalisées basées sur vos goûts
• Regardez les bandes-annonces et découvrez les détails du casting et de l'équipe

VOTRE LISTE, À VOTRE FAÇON
• Créez et organisez des listes de visionnage personnalisées
• Marquez films et épisodes comme vus d'un simple toucher
• Notez et ajoutez des commentaires personnels à chaque titre
• Programmez des notifications pour ne rater aucune sortie

TROUVEZ OÙ REGARDER
• Découvrez quels services de streaming proposent le film ou la série que vous cherchez
• Filtrez par votre région pour des résultats précis
• Accédez directement à l'application et lancez la lecture

SYNCHRONISÉ SUR TOUS VOS APPAREILS
• iCloud garde votre liste synchronisée partout
• Application Apple Watch pour un accès rapide au poignet
• Widgets sur l'écran d'accueil pour rester informé
• Disponible sur iPhone, iPad et Apple Watch

Téléchargez Streaming Now et ne perdez plus le fil de vos séries.""",

    "it": """\
Non perderti più nulla. Streaming Now ti aiuta a scoprire film e serie, gestire la tua watchlist e ricevere notifiche quando escono nuovi episodi e film.

SCOPRI & ESPLORA
• Sfoglia titoli di tendenza, popolari e in arrivo, aggiornati ogni giorno
• Esplora per genere con filtri intelligenti adatti al tuo umore
• Ricevi consigli personalizzati basati sui tuoi gusti
• Guarda trailer e scopri i dettagli su cast, troupe e produzione

LA TUA WATCHLIST, IL TUO STILE
• Crea e organizza watchlist con liste personalizzate
• Segna film ed episodi come visti con un solo tocco
• Valuta e aggiungi note personali a ogni titolo che guardi
• Imposta le notifiche per non perderti nessuna première

TROVA DOVE GUARDARE
• Scopri quali servizi di streaming hanno il film o la serie che cerchi
• Filtra per la tua regione per risultati accurati
• Vai direttamente all'app e inizia a guardare

SINCRONIZZATO SU TUTTI I TUOI DISPOSITIVI
• iCloud mantiene la tua watchlist sincronizzata ovunque
• App Apple Watch per un accesso rapido dal polso
• Widget nella schermata Home per restare aggiornato
• Disponibile su iPhone, iPad e Apple Watch

Scarica Streaming Now e non perdere più il filo di nessuna serie.""",

    "ja": """\
次に何を観るか、もう迷わない。Streaming Nowは映画やドラマの発見、ウォッチリストの管理、新エピソードや映画の公開通知をお届けします。

見つける・探す
• トレンド、人気、公開予定の作品を毎日更新でチェック
• ジャンル別のスマートフィルターで気分に合った作品を探索
• あなたの好みに基づいたパーソナライズされたおすすめを取得
• 予告編の視聴、キャスト・スタッフ・制作の詳細情報を確認

あなただけのウォッチリスト
• カスタムリストでウォッチリストを作成・整理
• 映画やエピソードをワンタップで視聴済みに
• 各作品に評価と個人メモを追加
• 通知を設定してプレミアや最終回を見逃さない

どこで観られるか確認
• 見たい映画やドラマを配信中のサービスをチェック
• お住まいの地域でフィルタリングして正確な情報を取得
• 配信アプリに直接ジャンプしてすぐに視聴開始

すべてのデバイスで同期
• iCloudでウォッチリストをどこでも同期
• Apple Watchアプリで手首からすばやくアクセス
• ホーム画面ウィジェットで次に観る作品をいつでも確認
• iPhone、iPad、Apple Watchに対応

Streaming Nowをダウンロードして、もうドラマを見失わない。""",

    "ko": """\
다음에 볼 작품을 놓치지 마세요. Streaming Now는 영화와 드라마를 발견하고, 시청 목록을 관리하고, 새 에피소드와 영화가 공개되는 순간 알림을 받을 수 있도록 도와줍니다.

발견하고 탐색하기
• 매일 업데이트되는 인기, 트렌드, 개봉 예정작 탐색
• 기분에 맞는 스마트 필터로 장르별 탐색
• 취향에 기반한 맞춤 추천 받기
• 예고편 시청 및 출연진, 제작진 상세 정보 확인

나만의 시청 목록
• 맞춤 리스트로 시청 목록 생성 및 정리
• 영화와 에피소드를 한 번의 탭으로 시청 완료 표시
• 모든 작품에 평점과 개인 메모 추가
• 알림 설정으로 프리미어나 피날레를 절대 놓치지 않기

어디서 볼 수 있는지 확인
• 원하는 영화나 드라마를 제공하는 스트리밍 서비스 확인
• 지역별 필터링으로 정확한 정보 제공
• 스트리밍 앱으로 바로 이동하여 시청 시작

모든 기기에서 동기화
• iCloud로 시청 목록을 어디서든 동기화
• Apple Watch 앱으로 손목에서 빠르게 확인
• 홈 화면 위젯으로 다음 볼 작품을 항상 파악
• iPhone, iPad, Apple Watch 지원

Streaming Now를 다운로드하고 다시는 드라마를 놓치지 마세요.""",

    "nl-NL": """\
Mis nooit meer wat je wilt kijken. Streaming Now helpt je films en series te ontdekken, je kijklijst bij te houden en meldingen te ontvangen zodra nieuwe afleveringen en films verschijnen.

ONTDEK & VERKEN
• Blader door trending, populaire en aankomende titels, dagelijks bijgewerkt
• Verken op genre met slimme filters passend bij je stemming
• Ontvang gepersonaliseerde aanbevelingen op basis van je smaak
• Bekijk trailers en ontdek details over cast, crew en productie

JOUW KIJKLIJST, JOUW MANIER
• Maak en organiseer kijklijsten met aangepaste lijsten
• Markeer films en afleveringen als gezien met één tik
• Beoordeel en voeg persoonlijke notities toe bij elke titel
• Stel meldingen in zodat je geen première mist

ONTDEK WAAR JE KUNT KIJKEN
• Bekijk welke streamingdiensten de film of serie hebben
• Filter op jouw regio voor nauwkeurige beschikbaarheid
• Spring direct naar de app en begin met kijken

GESYNCHRONISEERD OP AL JE APPARATEN
• iCloud houdt je kijklijst overal gesynchroniseerd
• Apple Watch-app voor snelle toegang op je pols
• Thuisscherm-widgets om op de hoogte te blijven
• Beschikbaar op iPhone, iPad en Apple Watch

Download Streaming Now en verlies nooit meer een serie uit het oog.""",

    "pl": """\
Nie przegap tego, co warto obejrzeć. Streaming Now pomaga odkrywać filmy i seriale, zarządzać listą do obejrzenia i dostawać powiadomienia w momencie premiery nowych odcinków i filmów.

ODKRYWAJ I EKSPLORUJ
• Przeglądaj popularne, trendy i nadchodzące tytuły aktualizowane codziennie
• Eksploruj według gatunku z inteligentnymi filtrami dopasowanymi do nastroju
• Otrzymuj spersonalizowane rekomendacje na podstawie swoich gustów
• Oglądaj zwiastuny i poznawaj szczegóły obsady, ekipy i produkcji

TWOJA LISTA, TWÓJ STYL
• Twórz i organizuj listy do obejrzenia z własnymi kategoriami
• Oznaczaj filmy i odcinki jako obejrzane jednym dotknięciem
• Oceniaj i dodawaj osobiste notatki do każdego tytułu
• Ustaw powiadomienia, żeby nie przegapić żadnej premiery

SPRAWDŹ, GDZIE OGLĄDAĆ
• Zobacz, które platformy streamingowe mają film lub serial, którego szukasz
• Filtruj według regionu, by uzyskać dokładne wyniki
• Przejdź bezpośrednio do aplikacji i zacznij oglądać

SYNCHRONIZACJA NA WSZYSTKICH URZĄDZENIACH
• iCloud utrzymuje Twoją listę zsynchronizowaną wszędzie
• Aplikacja Apple Watch do szybkiego dostępu z nadgarstka
• Widgety na ekranie głównym, by być na bieżąco
• Dostępne na iPhone, iPad i Apple Watch

Pobierz Streaming Now i nigdy nie zgub wątku żadnego serialu.""",

    "pt-BR": """\
Nunca perca o que assistir. O Streaming Now ajuda você a descobrir filmes e séries, gerenciar sua lista e receber notificações no momento em que novos episódios e filmes são lançados.

DESCUBRA E EXPLORE
• Navegue por títulos em alta, populares e em breve, atualizados diariamente
• Explore por gênero com filtros inteligentes que combinam com seu humor
• Receba recomendações personalizadas com base nos seus gostos
• Assista a trailers e conheça detalhes do elenco, equipe e produção

SUA LISTA, DO SEU JEITO
• Crie e organize listas de filmes com categorias personalizadas
• Marque filmes e episódios como assistidos com um toque
• Avalie e adicione notas pessoais a cada título que assistir
• Configure notificações para não perder nenhuma estreia ou final de temporada

DESCUBRA ONDE ASSISTIR
• Veja quais serviços de streaming têm o filme ou série que você quer
• Filtre por sua região para resultados precisos
• Vá direto ao app e comece a assistir

SINCRONIZADO EM TODOS OS SEUS DISPOSITIVOS
• iCloud mantém sua lista sincronizada em qualquer lugar
• App do Apple Watch para acesso rápido no pulso
• Widgets na tela inicial para ficar por dentro do que vem a seguir
• Disponível no iPhone, iPad e Apple Watch

Baixe o Streaming Now e nunca perca o fio de uma série.""",

    "tr": """\
Sıradakini asla kaçırmayın. Streaming Now film ve dizileri keşfetmenize, izleme listenizi yönetmenize ve yeni bölümler ile filmler çıktığı anda bildirim almanıza yardımcı olur.

KEŞFET VE ARAŞTIR
• Günlük güncellenen trend, popüler ve yakında çıkacak yapımları keşfedin
• Ruh halinize uygun akıllı filtrelerle türlere göre keşfedin
• Zevklerinize göre kişiselleştirilmiş öneriler alın
• Fragmanları izleyin, oyuncu kadrosu ve yapım detaylarını inceleyin

İZLEME LİSTENİZ, SİZİN TARZINIZ
• Özel listelerle izleme listeleri oluşturun ve düzenleyin
• Film ve bölümleri tek dokunuşla izlendi olarak işaretleyin
• Her yapıma puan verin ve kişisel notlar ekleyin
• Hiçbir prömiyeri kaçırmamak için bildirimleri ayarlayın

NEREDE İZLEYECEĞİNİZİ BULUN
• İstediğiniz film veya diziyi hangi platformların sunduğunu görün
• Bölgenize göre filtreleyin
• Doğrudan uygulamaya geçin ve izlemeye başlayın

TÜM CİHAZLARINIZDA SENKRONİZE
• iCloud izleme listenizi her yerde senkronize tutar
• Apple Watch uygulaması ile bileğinizden hızlı erişim
• Ana ekran widget'ları ile sıradakini takip edin
• iPhone, iPad ve Apple Watch'ta kullanılabilir

Streaming Now'u indirin ve bir diziyi bir daha asla kaybetmeyin.""",

    "zh-Hans": """\
不再错过精彩内容。Streaming Now 帮助您发现电影和电视剧、管理待看列表，并在新剧集和电影上映时第一时间收到通知。

发现与探索
• 浏览每日更新的热门、流行和即将上映的作品
• 通过智能筛选按类型探索，匹配您的心情
• 根据您的口味获取个性化推荐
• 观看预告片，了解演员阵容、制作团队和制作详情

您的片单 随心管理
• 创建和整理自定义待看列表
• 一键标记电影和剧集为已看
• 为每部作品打分并添加个人笔记
• 设置通知，不错过任何首播或大结局

查找观看平台
• 查看哪些流媒体服务提供您想看的电影或剧集
• 按地区筛选获取准确结果
• 直接跳转到应用开始观看

全设备同步
• iCloud 让您的片单随处同步
• Apple Watch 应用让您随时快速查看
• 主屏幕小组件帮您掌握接下来要看什么
• 支持 iPhone、iPad 和 Apple Watch

下载 Streaming Now，再也不会追丢任何剧集。""",
}

# ---------------------------------------------------------------------------
# Priority storefront acquisition positioning
# Lead with the differentiated Daily Emoji Movie Puzzle while retaining
# high-intent tracking and streaming discovery terms.
# ---------------------------------------------------------------------------
NAME.update({
    "fr-FR": "Streaming Now : Quiz Cinéma",
    "es-ES": "Streaming Now: Juego de Cine",
    "es-MX": "Streaming Now: Reto de Cine",
    "pt-BR": "Streaming Now: Quiz de Filmes",
})

SUBTITLE.update({
    "fr-FR": "Films emoji du jour & suivi",
    "es-ES": "Adivina cine con emojis",
    "es-MX": "Adivina pelis con emojis",
    "pt-BR": "Adivinhe filmes com emojis",
})

KEYWORDS.update({
    "fr-FR": "jeu,devinette,quotidien,watchlist,épisodes,saisons,où,regarder,streaming,sorties,suivi",
    "es-ES": "juego,emoji,diario,cartelera,watchlist,episodios,temporadas,dónde,ver,streaming,estrenos,lista",
    "es-MX": "juego,emoji,diario,pelis,watchlist,episodios,temporadas,dónde,ver,streaming,estrenos,lista",
    "pt-BR": "jogo,emoji,diário,cinema,watchlist,episódios,temporadas,onde,assistir,streaming,estreias,lista",
})

PROMOTIONAL_TEXT.update({
    "fr-FR": "Devinez le film avec les emojis du jour, enchaînez les défis, puis découvrez où regarder et gardez films et séries dans votre liste.",
    "es-ES": "Adivina la película con el juego diario de emojis, supera nuevos retos y descubre dónde verla mientras organizas tus series y películas.",
    "es-MX": "Adivina la peli con el reto diario de emojis, sigue jugando, descubre dónde verla y guarda tus series y películas en tu lista.",
    "pt-BR": "Adivinhe o filme no desafio diário de emojis, continue jogando, descubra onde assistir e organize filmes e séries na sua lista.",
})

PUZZLE_DESCRIPTION_INTRO = {
    "fr-FR": """PUZZLE CINÉMA QUOTIDIEN
Devinez le film grâce aux emojis du jour, débloquez des indices et enchaînez trois manches. Revenez chaque jour pour entretenir votre série.""",
    "es-ES": """JUEGO DIARIO DE CINE
Adivina la película con los emojis del día, desbloquea pistas y supera tres rondas. Vuelve cada día para mantener tu racha.""",
    "es-MX": """RETO DIARIO DE CINE
Adivina la peli con los emojis del día, desbloquea pistas y completa tres rondas. Regresa cada día para mantener tu racha.""",
    "pt-BR": """DESAFIO DIÁRIO DE FILMES
Adivinhe o filme com os emojis do dia, desbloqueie dicas e complete três rodadas. Volte todos os dias para manter sua sequência.""",
}

for locale, intro in PUZZLE_DESCRIPTION_INTRO.items():
    DESCRIPTION[locale] = f"{intro}\n\n{DESCRIPTION[locale]}"


# ---------------------------------------------------------------------------
# Character limit validation
# ---------------------------------------------------------------------------
LIMITS = {
    "name": 30,
    "subtitle": 30,
    "keywords": 100,
    "promotional_text": 170,
    "description": 4000,
}


def validate_all():
    """Validate all content against character limits."""
    errors = []
    for locale in LOCALES:
        n = NAME.get(locale, "")
        if len(n) > LIMITS["name"]:
            errors.append(f"  name [{locale}]: {len(n)}/{LIMITS['name']} -> \"{n}\"")
        s = SUBTITLE.get(locale, "")
        if len(s) > LIMITS["subtitle"]:
            errors.append(f"  subtitle [{locale}]: {len(s)}/{LIMITS['subtitle']} -> \"{s}\"")
        k = KEYWORDS.get(locale, "")
        if len(k) > LIMITS["keywords"]:
            errors.append(f"  keywords [{locale}]: {len(k)}/{LIMITS['keywords']} -> \"{k[:60]}...\"")
        p = PROMOTIONAL_TEXT.get(locale, "")
        if len(p) > LIMITS["promotional_text"]:
            errors.append(f"  promo [{locale}]: {len(p)}/{LIMITS['promotional_text']} -> \"{p[:60]}...\"")
        d = DESCRIPTION.get(locale, "")
        if len(d) > LIMITS["description"]:
            errors.append(f"  description [{locale}]: {len(d)}/{LIMITS['description']}")
    return errors


def main():
    parser = argparse.ArgumentParser(
        description="Generate localized App Store metadata for fastlane."
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print what would be created without writing files",
    )
    parser.add_argument(
        "--validate", action="store_true",
        help="Only validate character limits, don't write files",
    )
    parser.add_argument(
        "--output-dir", default=None,
        help="Output directory (default: fastlane/metadata in project root)",
    )
    args = parser.parse_args()

    # Validate limits
    errors = validate_all()
    if errors:
        print("Character limit violations:")
        for e in errors:
            print(e)
        if not args.validate:
            print()

    if args.validate:
        if not errors:
            print("All content within character limits!")
        for locale in LOCALES:
            n_len = len(NAME.get(locale, ""))
            s_len = len(SUBTITLE.get(locale, ""))
            k_len = len(KEYWORDS.get(locale, ""))
            p_len = len(PROMOTIONAL_TEXT.get(locale, ""))
            d_len = len(DESCRIPTION.get(locale, ""))
            print(f"\n--- {locale} ---")
            print(f"  name ({n_len}/{LIMITS['name']}): {NAME.get(locale, 'MISSING')}")
            print(f"  subtitle ({s_len}/{LIMITS['subtitle']}): {SUBTITLE.get(locale, 'MISSING')}")
            kw = KEYWORDS.get(locale, "MISSING")
            print(f"  keywords ({k_len}/{LIMITS['keywords']}): {kw[:70]}{'...' if len(kw) > 70 else ''}")
            pt = PROMOTIONAL_TEXT.get(locale, "MISSING")
            print(f"  promo ({p_len}/{LIMITS['promotional_text']}): {pt[:70]}{'...' if len(pt) > 70 else ''}")
            print(f"  description ({d_len}/{LIMITS['description']})")
        return

    # Resolve paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    output_dir = args.output_dir or os.path.join(project_root, "fastlane", "metadata")

    created = 0
    for locale in LOCALES:
        locale_dir = os.path.join(output_dir, locale)

        files = {
            "name.txt": NAME.get(locale, ""),
            "subtitle.txt": SUBTITLE.get(locale, ""),
            "keywords.txt": KEYWORDS.get(locale, ""),
            "promotional_text.txt": PROMOTIONAL_TEXT.get(locale, ""),
            "description.txt": DESCRIPTION.get(locale, ""),
            "release_notes.txt": RELEASE_NOTES.get(locale, ""),
            "support_url.txt": SUPPORT_URL,
            "marketing_url.txt": MARKETING_URL,
            "privacy_url.txt": PRIVACY_URL,
            "apple_tv_privacy_policy.txt": "",
        }

        for filename, content in files.items():
            filepath = os.path.join(locale_dir, filename)
            if args.dry_run:
                label = f"{len(content)} chars" if content else "empty"
                print(f"  {locale}/{filename} ({label})")
            else:
                os.makedirs(locale_dir, exist_ok=True)
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content + "\n" if content else "")
                created += 1

    if args.dry_run:
        print(f"\nWould create/update files for {len(LOCALES)} locales")
    else:
        print(f"Created {created} metadata files across {len(LOCALES)} locales in {output_dir}")


if __name__ == "__main__":
    main()
