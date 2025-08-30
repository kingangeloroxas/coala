import Foundation

struct SampleData {

    // Activities used across the UI
    private static let uiActivities: [String] = [
        "Hiking", "Pickleball", "Bowling", "Mini Golf", "Boba", "Movie",
        "Karaoke", "Dessert", "Cooking Class", "Theme Park",
        "Museum", "Yoga", "Coffee", "Brunch", "Golf",
        // Premium:
        "Snowboarding", "Paddleboarding", "Apple Picking"
    ]

    static let users: [User] = {
        var users: [User] = []

        // ---------------------------------------------------------------------
        // Hand-crafted seed examples
        // ---------------------------------------------------------------------
        users.append(contentsOf: [
            User(
                name: "Alice",
                age: 28,
                mbti: "ENFP",
                vibe: "Chill",
                ethnicity: "Asian",
                religion: "Christian",
                city: "Los Angeles",
                gender: "Female",
                badges: ["Planner Pro", "Team Player"],
                attendanceRating: 4.8,
                attendance: ["Hiking", "Boba"],
                photoName: "alice"
            ),
            User(
                name: "Bob",
                age: 32,
                mbti: "ISTJ",
                vibe: "Casual",
                ethnicity: "Caucasian",
                religion: "Atheist",
                city: "San Diego",
                gender: "Male",
                badges: ["Cool"],
                attendanceRating: 4.5,
                attendance: ["Bowling", "Movie"],
                photoName: "bob"
            ),
            User(
                name: "Carol",
                age: 25,
                mbti: "INFJ",
                vibe: "Party",
                ethnicity: "Hispanic",
                religion: "Catholic",
                city: "Irvine",
                gender: "Female",
                badges: ["Life of the Party"],
                attendanceRating: 4.9,
                attendance: ["Karaoke", "Theme Park"],
                photoName: "carol"
            )
        ])

        // ---------------------------------------------------------------------
        // Pools
        // ---------------------------------------------------------------------

        let ethnicities = ["Caucasian", "Asian", "African American", "Hispanic", "Native American"]
        let genders     = ["Male", "Female"]

        // Caucasian
        let caucasianFirstMale   = ["James","John","Robert","Michael","William","Thomas","Charles","Matthew","Andrew","Daniel","David","Joseph","Christopher","Anthony","Brian","Gregory","Patrick","Jason","Stephen","Eric"]
        let caucasianFirstFemale = ["Elizabeth","Jennifer","Patricia","Linda","Barbara","Emily","Hannah","Sarah","Samantha","Jessica","Lauren","Nicole","Rebecca","Victoria","Amy","Katherine","Rachel","Allison","Stephanie","Julia"]

        // Asian
        let asianFirstMale   = ["Hiro","Yuki","Kenji","Qiang","Lei","Anil","Ravi","Akira","Sora","Tao","Min","Jiho","Soo","Jin","Daichi","Haruto","Wei","Joon","Arun","Takeshi"]
        let asianFirstFemale = ["Aiko","Mei","Naoko","Rina","Hana","Priya","Yuna","Suki","Keiko","Ling","Sora","Minji","Eunji","Mika","Aya","Nari","Hyejin","Sana","Hitomi","Yuri"]

        // African American (using common US names)
        let blackFirstMale   = ["Marcus","Darius","Malik","Jamal","Tyrone","Andre","Xavier","Jalen","Micah","DeAndre","Malachi","Terrence","Dominique","Corey","Kendrick","Jerome","Desmond","Quentin","Derrick","Lamar"]
        let blackFirstFemale = ["Aaliyah","Imani","Nia","Aisha","Kenya","Deja","Latoya","Monique","Destiny","Trinity","Tiana","Kiara","Serenity","Makayla","Tanesha","Jasmine","Arielle","Zaria","Lanaya","Tamera"]

        // Hispanic
        let hispanicFirstMale   = ["Alejandro","Diego","Carlos","Miguel","Luis","Mateo","Santiago","Juan","Felipe","Andres","Javier","Ricardo","Rafael","Emilio","Hector","Pablo","Ramon","Tomas","Nicolas","Marco"]
        let hispanicFirstFemale = ["Sofia","Isabella","Camila","Valentina","Lucia","Mariana","Elena","Gabriela","Emilia","Renata","Daniela","Paula","Ximena","Romina","Adriana","Carolina","Fernanda","Bianca","Victoria","Claudia"]

        // Native American — NEW: distinct "mainstream American" first names,
        // separate from the Caucasian pool, paired with Native last names
        let nativeFirstMale   = ["Aaron","Brian","Eric","Kevin","Jason","Scott","Timothy","Steven","Derek","Nathan","Zachary","Trevor","Shawn","Logan","Connor","Ethan","Cameron","Jared","Tyler","Bryce"]
        let nativeFirstFemale = ["Ashley","Rachel","Lauren","Megan","Nicole","Amber","Crystal","Brittany","Heather","Melissa","Brooke","Courtney","Kayla","Paige","Danielle","Erin","Kelsey","Sabrina","Tiffany","Whitney"]

        // Last names
        let commonLast    = ["Smith","Johnson","Williams","Brown","Jones","Miller","Davis","Wilson","Anderson","Taylor","Moore","Jackson","Martin","Thompson","White","Harris","Clark","Lewis","Walker","Hall"]
        let asianLast     = ["Kim","Lee","Park","Nguyen","Tran","Wong","Chen","Liu","Zhang","Yamamoto","Sato","Tanaka","Khan","Singh","Patel"]
        let hispanicLast  = ["Garcia","Martinez","Hernandez","Lopez","Gonzalez","Perez","Sanchez","Ramirez","Torres","Flores","Diaz","Cruz","Reyes","Morales","Ortiz"]
        let nativeLast    = ["Begay","Yazzie","Tallbear","LoneWolf","Goodshield","Redbird","Blackwater","Whitefeather","TwoFeathers","Runningdeer"]

        // Other attributes
        let mbtiTypes = ["ENFP","ISTJ","INFJ","ENTP","ISFJ","INTP","ESFP","ESTJ","ENFJ","ISTP","INFP","ESTP","ENTJ","ESFJ","INTJ"]
        let vibes     = ["Chill", "Casual", "Party"]
        let religions = ["Christian","Catholic","Muslim","Jewish","Hindu","Buddhist","Atheist","Agnostic","Spiritual","None"]

        // California cities
        let citiesCA  = [
            "Los Angeles","San Diego","San Jose","San Francisco","Fresno","Sacramento","Long Beach","Oakland","Bakersfield","Anaheim",
            "Riverside","Stockton","Irvine","Chula Vista","Fremont","San Bernardino","Modesto","Oxnard","Fontana","Moreno Valley",
            "Huntington Beach","Glendale","Santa Clarita","Garden Grove","Santa Rosa","Oceanside","Rancho Cucamonga","Ontario","Elk Grove","Corona",
            "Lancaster","Palmdale","Salinas","Hayward","Pomona","Escondido","Sunnyvale","Torrance","Pasadena","Orange",
            "Fullerton","Visalia","Roseville","Concord","Thousand Oaks","Simi Valley","Vallejo","Berkeley","Santa Clara","Carlsbad",
            "Fairfield","Temecula","Clovis","Murrieta","El Monte","Antioch","Ventura","Richmond","Costa Mesa","West Covina",
            "Santa Maria","Norwalk","Daly City","Burbank","San Mateo","Rialto","El Cajon","Vista","Vacaville","San Marcos",
            "Compton","Hesperia","Mission Viejo","South Gate","Carson","Santa Monica","Westminster","Redding","Santa Barbara","Chico",
            "Whittier","Newport Beach","Hawthorne","San Leandro","San Rafael","Mountain View","Upland","Turlock","Fountain Valley","Livermore",
            "Tracy","Merced","Chino","Redwood City","Hemet","Lake Forest","Napa","Indio","Menifee","Arcadia"
        ]

        let badgesPool = ["Planner Pro","Team Player","Cool","Life of the Party","Wingman","Best Friend Material","Early Bird","Night Owl","Icebreaker"]

        // ---------------------------------------------------------------------
        // Helpers
        // ---------------------------------------------------------------------

        func randomFirstLast(for ethnicity: String, gender: String) -> (String, String) {
            switch ethnicity {
            case "Caucasian":
                let first = (gender == "Male" ? caucasianFirstMale.randomElement() : caucasianFirstFemale.randomElement()) ?? "Alex"
                let last  = commonLast.randomElement() ?? "Smith"
                return (first, last)

            case "Asian":
                let first = (gender == "Male" ? asianFirstMale.randomElement() : asianFirstFemale.randomElement()) ?? "Min"
                let last  = asianLast.randomElement() ?? "Kim"
                return (first, last)

            case "African American":
                let first = (gender == "Male" ? blackFirstMale.randomElement() : blackFirstFemale.randomElement()) ?? "Marcus"
                let last  = commonLast.randomElement() ?? "Johnson"
                return (first, last)

            case "Hispanic":
                let first = (gender == "Male" ? hispanicFirstMale.randomElement() : hispanicFirstFemale.randomElement()) ?? "Diego"
                let last  = hispanicLast.randomElement() ?? "Garcia"
                return (first, last)

            case "Native American":
                // NEW: different first-name pool (not reusing Caucasian), paired with Native last names.
                let first = (gender == "Male" ? nativeFirstMale.randomElement() : nativeFirstFemale.randomElement()) ?? "Aaron"
                let last  = nativeLast.randomElement() ?? "Begay"
                return (first, last)

            default:
                return ("Alex", "Doe")
            }
        }

        func fullName(first: String, last: String) -> String { "\(first) \(last)" }

        // ---------------------------------------------------------------------
        // Bulk synthetic users
        // ---------------------------------------------------------------------

        let targetCount = 500
        while users.count < targetCount {
            let ethnicity = ethnicities.randomElement()!
            let gender    = genders.randomElement()!

            let (first, last) = randomFirstLast(for: ethnicity, gender: gender)
            let name      = fullName(first: first, last: last)

            let age       = Int.random(in: 18...75)
            let mbti      = mbtiTypes.randomElement()!
            let vibe      = vibes.randomElement()!
            let religion  = religions.randomElement()!
            let city      = citiesCA.randomElement()!

            var attendance = Array(uiActivities.shuffled().prefix(Int.random(in: 1...4)))
            if attendance.count == 1,
               ["Snowboarding","Paddleboarding","Apple Picking"].contains(attendance[0]),
               let extra = uiActivities.filter({ $0 != attendance[0] }).randomElement() {
                attendance.append(extra)
            }

            let rating = Double.random(in: 3.0...5.0)
            let badges = Array(badgesPool.shuffled().prefix(Int.random(in: 0...3)))

            users.append(
                User(
                    name: name,
                    age: age,
                    mbti: mbti,
                    vibe: vibe,
                    ethnicity: ethnicity,
                    religion: religion,
                    city: city,
                    gender: gender,
                    badges: badges,
                    attendanceRating: rating,
                    attendance: attendance,
                    photoName: nil
                )
            )
        }

        // Ensure each activity has decent representation
        ensureCoverage(forAll: uiActivities, in: &users, minPerActivity: 60)
        return users
    }()

    // -------------------------------------------------------------------------
    // Coverage helpers (unchanged)
    // -------------------------------------------------------------------------

    private static func ensureCoverage(forAll activities: [String], in users: inout [User], minPerActivity: Int) {
        guard !users.isEmpty, minPerActivity > 0 else { return }
        for act in activities {
            ensureCoverage(for: act, in: &users, minCount: minPerActivity)
        }
    }

    private static func ensureCoverage(for activity: String, in users: inout [User], minCount: Int) {
        var current = users.reduce(0) { $0 + ( $1.attendance.contains(where: { $0.caseInsensitiveCompare(activity) == .orderedSame }) ? 1 : 0 ) }
        guard current < minCount else { return }
        var indices = Array(users.indices)
        indices.shuffle()
        for i in indices {
            if !users[i].attendance.contains(where: { $0.caseInsensitiveCompare(activity) == .orderedSame }) {
                users[i].attendance.append(activity)
                current += 1
                if current >= minCount { break }
            }
        }
    }
}

