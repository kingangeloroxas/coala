import Foundation

// MARK: - CityGeo
// Lat/Lon for California cities, plus Haversine distance.
// Lookup is case-insensitive (keys are stored lowercased).

enum CityGeo {
    struct LatLon { let lat: Double; let lon: Double }

    // Normalize key (lowercased, trimmed)
    private static func key(_ city: String) -> String {
        city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // Distance in miles between two city names (case-insensitive).
    // Returns nil if either city isn't known.
    static func distanceMiles(cityA: String?, cityB: String?) -> Double? {
        guard
            let a = cityA, let aa = coords[key(a)],
            let b = cityB, let bb = coords[key(b)]
        else { return nil }
        return haversineMiles(aa, bb)
    }

    // Haversine (miles)
    private static func haversineMiles(_ a: LatLon, _ b: LatLon) -> Double {
        let R = 3958.7613 // Earth radius in miles
        let dLat = deg2rad(b.lat - a.lat)
        let dLon = deg2rad(b.lon - a.lon)
        let la1 = deg2rad(a.lat)
        let la2 = deg2rad(b.lat)

        let h = sin(dLat/2) * sin(dLat/2) +
                cos(la1) * cos(la2) * sin(dLon/2) * sin(dLon/2)
        return 2 * R * asin(min(1, sqrt(h)))
    }

    private static func deg2rad(_ d: Double) -> Double { d * .pi / 180.0 }

    // MARK: - California City Map (no duplicate keys)
    // NOTE: keys must be lowercased!
    static let coords: [String: LatLon] = [
        // ——— Major Metros ———
        "los angeles": .init(lat: 34.052235, lon: -118.243683),
        "san diego": .init(lat: 32.715736, lon: -117.161087),
        "san jose": .init(lat: 37.338207, lon: -121.886330),
        "san francisco": .init(lat: 37.774929, lon: -122.419418),
        "fresno": .init(lat: 36.737797, lon: -119.787125),
        "sacramento": .init(lat: 38.581573, lon: -121.494400),
        "long beach": .init(lat: 33.770050, lon: -118.193741),
        "oakland": .init(lat: 37.804363, lon: -122.271111),
        "bakersfield": .init(lat: 35.373291, lon: -119.018715),
        "anaheim": .init(lat: 33.836594, lon: -117.914299),
        "riverside": .init(lat: 33.980601, lon: -117.375494),
        "stockton": .init(lat: 37.957702, lon: -121.290779),
        "irvine": .init(lat: 33.684567, lon: -117.826508),
        "chula vista": .init(lat: 32.640053, lon: -117.084198),
        "fremont": .init(lat: 37.548271, lon: -121.988571),
        "san bernardino": .init(lat: 34.108345, lon: -117.289765),
        "modesto": .init(lat: 37.639097, lon: -120.996878),
        "oxnard": .init(lat: 34.197605, lon: -119.177521),
        "fontana": .init(lat: 34.092232, lon: -117.435051),
        "moreno valley": .init(lat: 33.942467, lon: -117.229672),
        "huntington beach": .init(lat: 33.659484, lon: -117.998802),
        "glendale": .init(lat: 34.142506, lon: -118.255073),
        "santa ana": .init(lat: 33.745472, lon: -117.867653),
        "santa clarita": .init(lat: 34.391663, lon: -118.542587),
        "garden grove": .init(lat: 33.773907, lon: -117.941448),
        "ontario": .init(lat: 34.063346, lon: -117.650887),
        "rancho cucamonga": .init(lat: 34.106400, lon: -117.593108),
        "elk grove": .init(lat: 38.408799, lon: -121.371618),
        "corona": .init(lat: 33.875294, lon: -117.566437),

        // ——— Bay Area ———
        "sunnyvale": .init(lat: 37.368832, lon: -122.036346),
        "santa clara": .init(lat: 37.354107, lon: -121.955238),
        "mountain view": .init(lat: 37.386052, lon: -122.083851),
        "palo alto": .init(lat: 37.441883, lon: -122.143019),
        "redwood city": .init(lat: 37.485215, lon: -122.236355),
        "san mateo": .init(lat: 37.562992, lon: -122.325525),
        "daly city": .init(lat: 37.687924, lon: -122.470207),
        "south san francisco": .init(lat: 37.654656, lon: -122.407749),
        "berkeley": .init(lat: 37.871593, lon: -122.272743),
        "richmond": .init(lat: 37.935758, lon: -122.347750),
        "concord": .init(lat: 37.977978, lon: -122.031073),
        "walnut creek": .init(lat: 37.910078, lon: -122.065182),
        "pleasanton": .init(lat: 37.662431, lon: -121.874678),
        "livermore": .init(lat: 37.681873, lon: -121.768009),
        "san leandro": .init(lat: 37.724929, lon: -122.156076),
        "hayward": .init(lat: 37.668820, lon: -122.080796),
        "union city": .init(lat: 37.593392, lon: -122.043830),
        "milpitas": .init(lat: 37.432335, lon: -121.899574),
        "cupertino": .init(lat: 37.322998, lon: -122.032182),
        "campbell": .init(lat: 37.287167, lon: -121.949958),
        "morgan hill": .init(lat: 37.130501, lon: -121.654388),
        "gilroy": .init(lat: 37.005781, lon: -121.568275),
        "petaluma": .init(lat: 38.232417, lon: -122.636652),
        "santa rosa": .init(lat: 38.440467, lon: -122.714431),
        "napa": .init(lat: 38.297539, lon: -122.286865),
        "fairfield": .init(lat: 38.249358, lon: -122.039967),
        "vacaville": .init(lat: 38.356579, lon: -121.987747),
        "vallejo": .init(lat: 38.104086, lon: -122.256637),
        "antioch": .init(lat: 38.004921, lon: -121.805789),
        "pittsburg": .init(lat: 38.027976, lon: -121.884681),
        "brentwood": .init(lat: 37.931868, lon: -121.695786),
        "danville": .init(lat: 37.821593, lon: -121.999961),
        "san ramon": .init(lat: 37.779927, lon: -121.978015),

        // ——— Central Coast / Ventura / SB ———
        "ventura": .init(lat: 34.274647, lon: -119.229034),
        "simi valley": .init(lat: 34.269447, lon: -118.781479),
        "thousand oaks": .init(lat: 34.170559, lon: -118.837593),
        "santa barbara": .init(lat: 34.420830, lon: -119.698189),
        "goleta": .init(lat: 34.435829, lon: -119.827640),
        "san luis obispo": .init(lat: 35.282753, lon: -120.659616),
        "pismo beach": .init(lat: 35.142753, lon: -120.641282),
        "arroyo grande": .init(lat: 35.118587, lon: -120.590726),
        "santa maria": .init(lat: 34.953034, lon: -120.435719),
        "lompoc": .init(lat: 34.639150, lon: -120.457940),
        "salinas": .init(lat: 36.677737, lon: -121.655501),
        "monterey": .init(lat: 36.600238, lon: -121.894676),
        "carmel-by-the-sea": .init(lat: 36.555239, lon: -121.923287),
        "seaside": .init(lat: 36.611071, lon: -121.851617),
        "santa cruz": .init(lat: 36.974117, lon: -122.030792),
        "watsonville": .init(lat: 36.910231, lon: -121.756894),

        // ——— Inland Empire / High Desert ———
        "redlands": .init(lat: 34.055568, lon: -117.182541),
        "yucaipa": .init(lat: 34.033627, lon: -117.043091),
        "rialto": .init(lat: 34.106400, lon: -117.370323),
        "hesperia": .init(lat: 34.426388, lon: -117.300880),
        "victorville": .init(lat: 34.536106, lon: -117.291155),
        "apple valley": .init(lat: 34.500831, lon: -117.185875),
        "barstow": .init(lat: 34.895798, lon: -117.017284),
        "temecula": .init(lat: 33.493640, lon: -117.148361),
        "murrieta": .init(lat: 33.553915, lon: -117.213923),
        "menifee": .init(lat: 33.697147, lon: -117.185295),
        "hemet": .init(lat: 33.747520, lon: -116.971968), // (fixed: removed "hemets")
        "perris": .init(lat: 33.782520, lon: -117.228649),
        "beaumont": .init(lat: 33.929461, lon: -116.977249),
        "banning": .init(lat: 33.925571, lon: -116.876411),
        "upland": .init(lat: 34.097510, lon: -117.648388),
        "chino": .init(lat: 34.012234, lon: -117.688942),
        "chino hills": .init(lat: 33.989818, lon: -117.732582),
        "la verne": .init(lat: 34.100841, lon: -117.767834),
        "pomona": .init(lat: 34.055103, lon: -117.749991),
        "claremont": .init(lat: 34.096676, lon: -117.719780),

        // ——— Orange County (extras) ———
        "newport beach": .init(lat: 33.618912, lon: -117.928947),
        "laguna beach": .init(lat: 33.542717, lon: -117.785358),
        "laguna niguel": .init(lat: 33.522526, lon: -117.707553),
        "aliso viejo": .init(lat: 33.567684, lon: -117.725609),
        "mission viejo": .init(lat: 33.600021, lon: -117.671997),
        "lake forest": .init(lat: 33.646965, lon: -117.686106),
        "tustin": .init(lat: 33.745851, lon: -117.826166),
        "fullerton": .init(lat: 33.870365, lon: -117.924212),
        "brea": .init(lat: 33.916681, lon: -117.900063),
        "yorba linda": .init(lat: 33.888626, lon: -117.813112),
        "costa mesa": .init(lat: 33.641132, lon: -117.918671),
        "westminster": .init(lat: 33.751341, lon: -117.993992),
        "fountain valley": .init(lat: 33.709999, lon: -117.953667),
        "anaheim hills": .init(lat: 33.850000, lon: -117.740000),
        "seal beach": .init(lat: 33.741409, lon: -118.104768),
        "san clemente": .init(lat: 33.426971, lon: -117.611992),
        "dana point": .init(lat: 33.467235, lon: -117.698112),
        "san juan capistrano": .init(lat: 33.501693, lon: -117.662552),

        // ——— LA County (extras) ———
        "pasadena": .init(lat: 34.147785, lon: -118.144516),
        "burbank": .init(lat: 34.180839, lon: -118.308968),
        "glendora": .init(lat: 34.136119, lon: -117.865341),
        "azusa": .init(lat: 34.133619, lon: -117.907562),
        "duarte": .init(lat: 34.139729, lon: -117.977287),
        "monrovia": .init(lat: 34.144261, lon: -118.001948),
        "arcadia": .init(lat: 34.136719, lon: -118.041979),
        "alhambra": .init(lat: 34.095287, lon: -118.127014),
        "montebello": .init(lat: 34.009460, lon: -118.105743),
        "whittier": .init(lat: 33.979179, lon: -118.032844),
        "downey": .init(lat: 33.940108, lon: -118.133159),
        "norwalk": .init(lat: 33.902237, lon: -118.081733),
        "cerritos": .init(lat: 33.858349, lon: -118.064789),
        "lakewood": .init(lat: 33.853626, lon: -118.133957),
        "redondo beach": .init(lat: 33.849182, lon: -118.388405),
        "manhattan beach": .init(lat: 33.884736, lon: -118.410909),
        "hermosa beach": .init(lat: 33.862236, lon: -118.399519),
        "torrance": .init(lat: 33.835293, lon: -118.340628),
        "inglewood": .init(lat: 33.961681, lon: -118.353127),
        "west hollywood": .init(lat: 34.090010, lon: -118.406849),
        "beverly hills": .init(lat: 34.073620, lon: -118.400356),
        "santa monica": .init(lat: 34.019454, lon: -118.491191),
        "malibu": .init(lat: 34.025921, lon: -118.779757),

        // ——— Central Valley / NorCal ———
        "turlock": .init(lat: 37.494656, lon: -120.846595),
        "ceres": .init(lat: 37.594933, lon: -120.957710),
        "merced": .init(lat: 37.302163, lon: -120.482967),
        "madera": .init(lat: 36.961338, lon: -120.060722),
        "visalia": .init(lat: 36.330230, lon: -119.292061),
        "hanford": .init(lat: 36.327450, lon: -119.645684),
        "porterville": .init(lat: 36.065231, lon: -119.016769),
        "lodi": .init(lat: 38.134148, lon: -121.272453),
        "tracy": .init(lat: 37.739651, lon: -121.425224),
        "yuba city": .init(lat: 39.140449, lon: -121.616913),
        "chico": .init(lat: 39.728494, lon: -121.837479),
        "redding": .init(lat: 40.586540, lon: -122.391678),
        "eureka": .init(lat: 40.802071, lon: -124.163673),
        "ukiah": .init(lat: 39.150172, lon: -123.207783),
        "davis": .init(lat: 38.544907, lon: -121.740517),
        "woodland": .init(lat: 38.678516, lon: -121.773298),
        "roseville": .init(lat: 38.752125, lon: -121.288010),
        "rocklin": .init(lat: 38.790733, lon: -121.235783),
        "lincoln": .init(lat: 38.891567, lon: -121.293008),
        "el dorado hills": .init(lat: 38.685736, lon: -121.082168),
        "folsom": .init(lat: 38.677959, lon: -121.176064),
        "placerville": .init(lat: 38.729625, lon: -120.798546),
        "auburn": .init(lat: 38.896565, lon: -121.076890),
        "grass valley": .init(lat: 39.219060, lon: -121.061060),
        "nevada city": .init(lat: 39.261559, lon: -121.016059),

        // ——— Desert / Coachella ———
        "palm springs": .init(lat: 33.830296, lon: -116.545292),
        "cathedral city": .init(lat: 33.780541, lon: -116.466803),
        "palm desert": .init(lat: 33.722245, lon: -116.374456),
        "la quinta": .init(lat: 33.663357, lon: -116.310010),
        "indio": .init(lat: 33.720577, lon: -116.215561),
        "coachella": .init(lat: 33.680300, lon: -116.173897),
        "desert hot springs": .init(lat: 33.961121, lon: -116.501678),
        "blythe": .init(lat: 33.610310, lon: -114.596374),

        // ——— San Diego County (extras) ———
        "carlsbad": .init(lat: 33.158093, lon: -117.350594),
        "oceanside": .init(lat: 33.195869, lon: -117.379483),
        "vista": .init(lat: 33.200037, lon: -117.242536),
        "san marcos": .init(lat: 33.143372, lon: -117.166144),
        "escondido": .init(lat: 33.119206, lon: -117.086421),
        "poway": .init(lat: 32.962823, lon: -117.035865),
        "la jolla": .init(lat: 32.832811, lon: -117.271271),
        "encinitas": .init(lat: 33.036987, lon: -117.291981),
        "del mar": .init(lat: 32.959489, lon: -117.265314),
        "imperial beach": .init(lat: 32.583944, lon: -117.113083),
        "national city": .init(lat: 32.678108, lon: -117.099197),
        "el cajon": .init(lat: 32.794773, lon: -116.962527),
        "la mesa": .init(lat: 32.767829, lon: -117.023084),
        "santee": .init(lat: 32.838383, lon: -116.973917),

        // ——— Tahoe / Sierra ———
        "south lake tahoe": .init(lat: 38.939926, lon: -119.977186),
        "truckee": .init(lat: 39.327962, lon: -120.183253),
        "mammoth lakes": .init(lat: 37.648546, lon: -118.972079),
        "bishop": .init(lat: 37.363537, lon: -118.395112),
    ]
}

