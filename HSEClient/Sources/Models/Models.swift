import Foundation

// Shapes below match real responses verified against api.hseapp.ru.

// GET /v3/dump/me
struct Profile: Decodable, Identifiable {
    let id: String
    let fullName: String
    let email: String
    let description: String?
    let type: String?
    let avatarUrl: String?
    let education: [Education]?

    struct Education: Decodable {
        let programTitle: String?
        let facultyTitle: String?
        let startYear: String?
        let degreeLevel: String?
        let groupTitle: String?

        enum CodingKeys: String, CodingKey {
            case programTitle = "program_title"
            case facultyTitle = "faculty_title"
            case startYear = "start_year"
            case degreeLevel = "degree_level"
            case groupTitle = "group_title"
        }

        /// The backend's `start_year` is unreliable (off by a year — it reflects the
        /// curriculum plan, not enrolment). The true admission year is encoded in the
        /// group code: "БПИ262" → 2026, "БПМ211" → 2021. Fall back to start_year.
        var admissionYear: String? {
            if let g = groupTitle, let y = Education.yearFromGroup(g) { return String(y) }
            return startYear
        }

        static func yearFromGroup(_ group: String) -> Int? {
            guard let first = group.firstIndex(where: { $0.isNumber }) else { return nil }
            let digits = group[first...].prefix { $0.isNumber }
            guard digits.count >= 2, let two = Int(digits.prefix(2)) else { return nil }
            return 2000 + two
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, email, description, type, education
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
    }
}

// GET /v3/ruz/lessons  (array)
struct Lesson: Decodable, Identifiable {
    let id: String
    let discipline: String?
    let type: String?
    let building: String?
    let auditorium: String?
    let dateStart: Date
    let dateEnd: Date
    let lecturer: String?
    let lecturerEmail: String?
    let lecturerAvatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, discipline, type, building, auditorium, lecturer
        case dateStart = "date_start"
        case dateEnd = "date_end"
        case lecturerEmail = "lecturer_email"
        case lecturerAvatarUrl = "lecturer_avatar_url"
    }

    /// True while this lesson is happening right now.
    var isNow: Bool { (dateStart...dateEnd).contains(Date()) }
}

/// A person we can open a profile for (teacher from a lesson, etc.).
struct PersonRef: Identifiable, Hashable {
    let email: String
    let name: String
    var id: String { email }
}

// GET /v2/grades
struct GradesResponse: Decodable {
    let items: [Grade]
    let selectedAcademicYear: String?

    enum CodingKeys: String, CodingKey {
        case items
        case selectedAcademicYear = "selected_academic_year"
    }
}

struct Grade: Decodable, Identifiable {
    let id: String
    let discipline: String
    let typeRaw: String?
    let moduleName: String?
    let academicYear: String?
    let credits: Int?

    enum CodingKeys: String, CodingKey {
        case id, discipline, credits
        case typeRaw = "type_raw"
        case moduleName = "module_name"
        case academicYear = "academic_year"
    }
}

// POST /v2/deadlines  {"is_completed": Bool}
struct DeadlinesResponse: Decodable {
    let nextCursor: String?
    let items: [Deadline]

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct Deadline: Decodable, Identifiable {
    let id: String
    let title: String
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title
        case expiresAt = "expires_at"
    }
}

// GET /v3/dump/search?q=&type=   (type: nil → люди; GROUP; AUDITORIUM)
struct SearchResult: Decodable, Identifiable, Hashable {
    let id: String
    let email: String?
    let fullName: String?
    let label: String?
    let room: String?
    let description: String?
    let type: String?
    let auditoriumType: String?

    enum CodingKeys: String, CodingKey {
        case id, email, label, room, description, type
        case fullName = "full_name"
        case auditoriumType = "auditorium_type"
    }

    /// Human-friendly primary line.
    var title: String { fullName ?? label ?? room ?? id }
}

// GET /v3/dump/email/{email}  — full profile of any found person (UserDataEntity).
// Decoded defensively: the server returns different fields for students vs staff.
struct PersonProfile: Decodable {
    var id: String?
    var fullName: String?
    var email: String?
    var type: String?
    var avatarUrl: String?
    var description: String?
    var birthDate: String?
    var campus: String?
    var isTimetableAvailable: Bool
    var staffEmailPersonal: String?
    var staffPhoneMobile: String?
    var staffAddress: String?
    var positions: [StaffPosition]
    var education: [Profile.Education]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func s(_ k: CodingKeys) -> String? { try? c.decodeIfPresent(String.self, forKey: k) ?? nil }
        id = s(.id); fullName = s(.fullName); email = s(.email); type = s(.type)
        avatarUrl = s(.avatarUrl); description = s(.description); birthDate = s(.birthDate); campus = s(.campus)
        staffEmailPersonal = s(.staffEmailPersonal); staffPhoneMobile = s(.staffPhoneMobile); staffAddress = s(.staffAddress)
        isTimetableAvailable = (try? c.decodeIfPresent(Bool.self, forKey: .isTimetableAvailable) ?? false) ?? false
        positions = (try? c.decodeIfPresent([StaffPosition].self, forKey: .positions) ?? []) ?? []
        education = (try? c.decodeIfPresent([Profile.Education].self, forKey: .education) ?? []) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case id, email, type, description, campus, education
        case fullName = "full_name"
        case avatarUrl = "avatar_url"
        case birthDate = "birth_date"
        case isTimetableAvailable = "is_timetable_available"
        case staffEmailPersonal = "staff_email_personal"
        case staffPhoneMobile = "staff_phone_mobile"
        case staffAddress = "staff_address"
        case positions = "staff_positions"
    }
}

struct StaffPosition: Decodable, Hashable {
    var title: String?
    var department: String?
    var subdivision: String?

    enum CodingKeys: String, CodingKey {
        case title, department, subdivision
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try? c.decodeIfPresent(String.self, forKey: .title) ?? nil
        department = try? c.decodeIfPresent(String.self, forKey: .department) ?? nil
        subdivision = try? c.decodeIfPresent(String.self, forKey: .subdivision) ?? nil
    }

    var line: String? {
        [title, department ?? subdivision].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

// POST /v3/dump/buildings/groups  → [{campus, buildings:[Building]}]
struct Campus: Decodable {
    let campus: String?
    let buildings: [Building]?
}

struct Building: Decodable, Identifiable, Hashable {
    let id: String
    let name: String?
    let address: String?
    let campus: String?

    enum CodingKeys: String, CodingKey { case id, name, address, campus }
}

// POST /rooms/free  → {building, rooms:[FreeRoom]}
struct FreeRoomsResponse: Decodable {
    let rooms: [FreeRoom]
}

struct FreeRoom: Decodable, Identifiable {
    let id: String
    let fullName: String?
    let auditoriumFloor: String?
    let auditoriumType: String?
    let auditoriumBuilding: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case auditoriumFloor = "auditorium_floor"
        case auditoriumType = "auditorium_type"
        case auditoriumBuilding = "auditorium_building"
    }
}

// GET /v2/notifications/feed
struct NotificationsResponse: Decodable {
    let nextCursor: String?
    let items: [Notice]

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

struct Notice: Decodable, Identifiable {
    let externalId: String?
    let title: String?
    let content: String?
    let category: String?
    let image: String?

    var id: String { externalId ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case title, content, category, image
        case externalId = "external_id"
    }
}

// GET /food/cafes  →  [ { "cafes": [Cafe] } ]
struct CafeGroup: Decodable {
    let cafes: [Cafe]
}

struct Cafe: Decodable, Identifiable {
    let cafeId: String
    let cafeName: String
    let openingHours: [OpeningHour]?

    var id: String { cafeId }

    enum CodingKeys: String, CodingKey {
        case cafeId = "cafe_id"
        case cafeName = "cafe_name"
        case openingHours = "opening_hours"
    }
}

struct OpeningHour: Decodable {
    let dayOfWeek: String
    let isOpen: Bool
    let startTime: String?
    let endTime: String?

    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case isOpen = "is_open"
        case startTime = "start_time"
        case endTime = "end_time"
    }
}
