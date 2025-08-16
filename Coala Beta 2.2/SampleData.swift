import Foundation

struct SampleData {
    static let users: [User] = {
        // --- 1) Keep your originals ---
        var users: [User] = [
            User(
                name: "Alice",
                age: 28,
                mbti: "ENFP",
                vibe: "Chill",
                ethnicity: "Asian",
                religion: "Christian",
                city: "Los Angeles",
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
                badges: ["Life of the Party"],
                attendanceRating: 4.9,
                attendance: ["Karaoke", "Theme Park"],
                photoName: "carol"
            )
        ]

        // --- 2) Random pools ---
        let ethnicities = ["Caucasian", "Asian", "African American", "Hispanic", "Native American"]

        // Representative first/last names across groups (not exhaustive)
        let caucasianFirst = ["James","John","Robert","Michael","William","Elizabeth","Jennifer","Patricia","Linda","Barbara","Thomas","Charles","Matthew","Emily","Hannah","Sarah","Samantha","Jessica","Andrew","Lauren"]
        let asianFirst      = ["Hiro","Yuki","Kenji","Aiko","Min","Jiho","Soo","Mei","Qiang","Lei","Anil","Priya","Ravi","Akira","Naoko","Sora","Hana","Tao","Rina","Nikhil"]
        let blackFirst      = ["Aaliyah","Imani","Nia","Darius","Malik","Jamal","Tyrone","Aisha","Kenya","Deja","Latoya","Monique","Andre","Marcus","Xavier","Destiny","Trinity","Jalen","Jasper","Micah"]
        let hispanicFirst   = ["Alejandro","Diego","Carlos","Miguel","Luis","Sofia","Isabella","Camila","Valentina","Lucia","Mateo","Santiago","Juan","Felipe","Mariana","Elena","Gabriela","Andres","Emilia","Renata"]
        let nativeFirst     = ["Aponi","Tala","Nayeli","Onida","Takoda","Kiona","Elan","Kaya","Dyami","Hania","Mika","Nodin","Sakari","Wyanet","Yasti","Kitchi","Lomasi","Misu","Naira","Pavati"]

        let commonLast      = ["Smith","Johnson","Williams","Brown","Jones","Miller","Davis","Garcia","Rodriguez","Martinez","Hernandez","Lopez","Gonzalez","Wilson","Anderson","Thomas","Taylor","Moore","Jackson","Martin"]
        let asianLast       = ["Kim","Lee","Park","Nguyen","Tran","Wong","Chen","Liu","Zhang","Yamamoto","Sato","Tanaka","Khan","Singh","Patel"]
        let hispanicLast    = ["Garcia","Martinez","Hernandez","Lopez","Gonzalez","Perez","Sanchez","Ramirez","Torres","Flores","Diaz","Cruz","Reyes","Morales","Ortiz"]
        let nativeLast      = ["Begay","Yazzie","Tallbear","LoneWolf","Goodshield","Redbird","Blackwater","Whitefeather","TwoFeathers","Runningdeer"]

        let mbtiTypes = ["ENFP","ISTJ","INFJ","ENTP","ISFJ","INTP","ESFP","ESTJ","ENFJ","ISTP","INFP","ESTP","ENTJ","ESFJ","INTJ"]
        let vibes     = ["Chill", "Casual", "Party"]          // keep consistent with your app
        let religions = ["Christian","Catholic","Muslim","Jewish","Hindu","Buddhist","Atheist","Agnostic","Spiritual","None"]

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

        let badgesPool   = ["Planner Pro","Team Player","Cool","Life of the Party","Wingman","Best Friend Material","Early Bird","Night Owl","Icebreaker"]
        let activities   = ["Hiking","Boba","Bowling","Movie","Karaoke","Theme Park","Cooking Class","Mini Golf","Pickleball","Dessert","Museum","Yoga","Coffee","Brunch","Boba","Golf"]

        func randomName(for ethnicity: String, index: Int) -> String {
            let first: String
            let last: String

            switch ethnicity {
            case "Asian":
                first = (asianFirst.randomElement() ?? "Min")
                last  = (asianLast.randomElement() ?? "Kim")
            case "African American":
                first = (blackFirst.randomElement() ?? "Marcus")
                last  = (commonLast.randomElement() ?? "Johnson")
            case "Hispanic":
                first = (hispanicFirst.randomElement() ?? "Diego")
                last  = (hispanicLast.randomElement() ?? "Garcia")
            case "Native American":
                first = (nativeFirst.randomElement() ?? "Takoda")
                last  = (nativeLast.randomElement() ?? "Begay")
            default: // Caucasian or fallback
                first = (caucasianFirst.randomElement() ?? "James")
                last  = (commonLast.randomElement() ?? "Smith")
            }

            // Mild disambiguation to avoid many exact duplicates
            return "\(first) \(last)"
        }

        // --- 3) Generate until we reach 500 total ---
        while users.count < 500 {
            let ethnicity = ethnicities.randomElement()!
            let name = randomName(for: ethnicity, index: users.count)

            let age = Int.random(in: 18...75)
            let mbti = mbtiTypes.randomElement()!
            let vibe = vibes.randomElement()!
            let religion = religions.randomElement()!
            let city = citiesCA.randomElement()!

            let badges = Array(badgesPool.shuffled().prefix(Int.random(in: 0...3)))
            let attendance = Array(activities.shuffled().prefix(Int.random(in: 1...4)))
            let rating = Double.random(in: 3.0...5.0)

            users.append(
                User(
                    name: name,
                    age: age,
                    mbti: mbti,
                    vibe: vibe,
                    ethnicity: ethnicity,
                    religion: religion,
                    city: city,
                    badges: badges,
                    attendanceRating: rating,
                    attendance: attendance,
                    photoName: nil
                )
            )
        }

        return users
    }()
}

