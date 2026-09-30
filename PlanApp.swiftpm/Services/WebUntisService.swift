import Foundation

/// WebUntis JSON-RPC 2.0 API Client
public final class WebUntisService {
    public static let shared = WebUntisService()

    private let urlSession: URLSession

    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 30.0
        self.urlSession = URLSession(configuration: config)
    }

    public enum UntisError: LocalizedError {
        case invalidURL
        case invalidResponse
        case apiError(code: Int, message: String)
        case authenticationFailed(String)
        case networkError(String)
        case decodingError(String)

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Ungültige Server-URL oder Schulname. Bitte prüfen."
            case .invalidResponse:
                return "Ungültige Antwort vom WebUntis-Server."
            case .apiError(let code, let message):
                if code == -8520 || code == -8504 {
                    return "Anmeldung fehlgeschlagen: Benutzername oder Passwort falsch (Fehler \(code))."
                }
                return "Untis-Fehler (\(code)): \(message)"
            case .authenticationFailed(let reason):
                return "Authentifizierung fehlgeschlagen: \(reason)"
            case .networkError(let msg):
                return "Netzwerkfehler: \(msg)"
            case .decodingError(let msg):
                return "Datenformatfehler: \(msg)"
            }
        }
    }

    // MARK: - JSON-RPC Request Helper

    /// Platzhalter für RPC-Antworten, deren Inhalt nicht ausgewertet wird (z.B. `logout`).
    /// `[String: Any]` kann nicht `Decodable` sein, daher dieser tolerante Typ,
    /// der jede beliebige JSON-Antwort akzeptiert.
    private struct IgnoredRPCResult: Decodable {
        init(from decoder: Decoder) throws {}
    }

    private func sendRPCRequest<T: Decodable>(
        endpoint: URL,
        method: String,
        params: [String: Any],
        sessionId: String? = nil
    ) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("PlanApp-iPad", forHTTPHeaderField: "User-Agent")

        if let sessionId = sessionId, !sessionId.isEmpty {
            request.setValue("JSESSIONID=\(sessionId)", forHTTPHeaderField: "Cookie")
        }

        let body: [String: Any] = [
            "id": "req_\(UUID().uuidString.prefix(8))",
            "method": method,
            "params": params,
            "jsonrpc": "2.0"
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body, options: []) else {
            throw UntisError.decodingError("Request-Body konnte nicht serialisiert werden.")
        }
        request.httpBody = httpBody

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            throw UntisError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw UntisError.invalidResponse
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UntisError.decodingError("Server lieferte kein gültiges JSON.")
        }

        if let errorDict = json["error"] as? [String: Any] {
            let code = errorDict["code"] as? Int ?? -1
            let message = errorDict["message"] as? String ?? "Unbekannter Fehler"
            throw UntisError.apiError(code: code, message: message)
        }

        guard let result = json["result"] else {
            throw UntisError.decodingError("Kein 'result' in der Server-Antwort.")
        }

        let resultData = try JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed])
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: resultData)
        } catch {
            throw UntisError.decodingError("Antwort konnte nicht in das Zielformat konvertiert werden: \(error.localizedDescription)")
        }
    }

    // MARK: - API Methods

    public struct AuthResult: Decodable {
        public let sessionId: String
        public let personType: Int?
        public let personId: Int?
        public let klasseId: Int?
    }

    /// Meldet sich bei WebUntis an und gibt die AuthResult zurück
    public func authenticate(credentials: UntisCredentials) async throws -> AuthResult {
        guard let url = credentials.rpcEndpointURL else {
            throw UntisError.invalidURL
        }

        let params: [String: Any] = [
            "user": credentials.user,
            "password": credentials.password,
            "client": "PlanApp"
        ]

        return try await sendRPCRequest(endpoint: url, method: "authenticate", params: params)
    }

    public struct UntisTimegridDay: Decodable {
        public let day: Int?
        public let timeUnits: [UntisTimeUnit]
    }

    public struct UntisTimeUnit: Decodable {
        public let name: String?
        public let startTime: Int
        public let endTime: Int
    }

    /// Ruft die Stundenzeiten (Timegrid) der Schule ab
    public func fetchTimegrid(credentials: UntisCredentials, sessionId: String) async throws -> [Period] {
        guard let url = credentials.rpcEndpointURL else {
            throw UntisError.invalidURL
        }

        let days: [UntisTimegridDay] = try await sendRPCRequest(
            endpoint: url,
            method: "getTimegridUnits",
            params: [:],
            sessionId: sessionId
        )

        var uniqueUnits: [Int: (start: Int, end: Int, name: String)] = [:]
        for day in days {
            for unit in day.timeUnits {
                let start = unit.startTime
                if uniqueUnits[start] == nil {
                    uniqueUnits[start] = (start: unit.startTime, end: unit.endTime, name: unit.name ?? "")
                }
            }
        }

        let sorted = uniqueUnits.values.sorted { $0.start < $1.start }
        var resultPeriods: [Period] = []

        for (index, unit) in sorted.enumerated() {
            let periodNumber = index + 1
            let name = unit.name.isEmpty ? "\(periodNumber)" : unit.name
            let startTime = Period.formatUntisTime(unit.start)
            let endTime = Period.formatUntisTime(unit.end)
            resultPeriods.append(Period(periodNumber: periodNumber, name: name, startTime: startTime, endTime: endTime))
        }

        return resultPeriods.isEmpty ? Period.defaultPeriods : resultPeriods
    }

    public struct UntisLessonElement: Decodable {
        public let id: Int?
        public let date: Int // YYYYMMDD z.B. 20260930
        public let startTime: Int // 800
        public let endTime: Int   // 845
        public let kl: [UntisNameElement]? // Klassen
        public let te: [UntisTeacherElement]? // Lehrer
        public let su: [UntisSubjectElement]? // Fächer
        public let ro: [UntisRoomElement]?    // Räume
        public let code: String?              // "cancelled", "irregular" etc.
        public let substText: String?          // Vertretungstext
        public let statflags: String?         // Status-Flags
        public let lstype: String?
    }

    /// WebUntis liefert in Stundenplan-Einträgen je nach Server-Version entweder
    /// Namen oder lediglich IDs. Außerdem kommen sowohl `longname` als auch
    /// `longName` vor. Die eigenen Decoder unterstützen beide Varianten.
    public struct UntisNameElement: Decodable {
        public let id: Int?
        public let name: String?
        public let longname: String?

        private enum CodingKeys: String, CodingKey { case id, name, longname, longName }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decodeIfPresent(Int.self, forKey: .id)
            name = try values.decodeIfPresent(String.self, forKey: .name)
            let legacyLongName = try values.decodeIfPresent(String.self, forKey: .longname)
            let modernLongName = try values.decodeIfPresent(String.self, forKey: .longName)
            longname = legacyLongName ?? modernLongName
        }
    }

    public struct UntisTeacherElement: Decodable {
        public let id: Int?
        public let name: String?
        public let orgname: String?
        public let longname: String?

        private enum CodingKeys: String, CodingKey { case id, name, orgname, longname, longName }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decodeIfPresent(Int.self, forKey: .id)
            name = try values.decodeIfPresent(String.self, forKey: .name)
            orgname = try values.decodeIfPresent(String.self, forKey: .orgname)
            let legacyLongName = try values.decodeIfPresent(String.self, forKey: .longname)
            let modernLongName = try values.decodeIfPresent(String.self, forKey: .longName)
            longname = legacyLongName ?? modernLongName
        }
    }

    public struct UntisSubjectElement: Decodable {
        public let id: Int?
        public let name: String?
        public let longname: String?

        private enum CodingKeys: String, CodingKey { case id, name, longname, longName }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decodeIfPresent(Int.self, forKey: .id)
            name = try values.decodeIfPresent(String.self, forKey: .name)
            let legacyLongName = try values.decodeIfPresent(String.self, forKey: .longname)
            let modernLongName = try values.decodeIfPresent(String.self, forKey: .longName)
            longname = legacyLongName ?? modernLongName
        }
    }

    public struct UntisRoomElement: Decodable {
        public let id: Int?
        public let name: String?
        public let orgname: String?
        public let longname: String?

        private enum CodingKeys: String, CodingKey { case id, name, orgname, longname, longName }

        public init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            id = try values.decodeIfPresent(Int.self, forKey: .id)
            name = try values.decodeIfPresent(String.self, forKey: .name)
            orgname = try values.decodeIfPresent(String.self, forKey: .orgname)
            let legacyLongName = try values.decodeIfPresent(String.self, forKey: .longname)
            let modernLongName = try values.decodeIfPresent(String.self, forKey: .longName)
            longname = legacyLongName ?? modernLongName
        }
    }

    private struct MasterData {
        var subjects: [Int: UntisSubjectElement] = [:]
        var teachers: [Int: UntisTeacherElement] = [:]
        var rooms: [Int: UntisRoomElement] = [:]
        var classes: [Int: UntisNameElement] = [:]
    }

    private func fetchMasterData(credentials: UntisCredentials, sessionId: String) async -> MasterData {
        guard let url = credentials.rpcEndpointURL else { return MasterData() }

        // Manche Schulen sperren einzelne Stammdaten-Endpunkte. Deshalb darf ein
        // fehlender Endpunkt die eigentlichen Stundenplandaten nicht verhindern.
        let subjects: [UntisSubjectElement] = (try? await sendRPCRequest(
            endpoint: url, method: "getSubjects", params: [:], sessionId: sessionId
        )) ?? []
        let teachers: [UntisTeacherElement] = (try? await sendRPCRequest(
            endpoint: url, method: "getTeachers", params: [:], sessionId: sessionId
        )) ?? []
        let rooms: [UntisRoomElement] = (try? await sendRPCRequest(
            endpoint: url, method: "getRooms", params: [:], sessionId: sessionId
        )) ?? []
        let classes: [UntisNameElement] = (try? await sendRPCRequest(
            endpoint: url, method: "getKlassen", params: [:], sessionId: sessionId
        )) ?? []

        return MasterData(
            subjects: subjects.reduce(into: [:]) { if let id = $1.id { $0[id] = $1 } },
            teachers: teachers.reduce(into: [:]) { if let id = $1.id { $0[id] = $1 } },
            rooms: rooms.reduce(into: [:]) { if let id = $1.id { $0[id] = $1 } },
            classes: classes.reduce(into: [:]) { if let id = $1.id { $0[id] = $1 } }
        )
    }

    /// Ruft den Stundenplan für einen Zeitraum (Woche) ab
    public func fetchTimetable(
        credentials: UntisCredentials,
        sessionId: String,
        startDate: Date,
        endDate: Date,
        personId: Int?,
        personType: Int?,
        periods: [Period]
    ) async throws -> [Lesson] {
        guard let url = credentials.rpcEndpointURL else {
            throw UntisError.invalidURL
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        guard let startInt = Int(formatter.string(from: startDate)),
              let endInt = Int(formatter.string(from: endDate)) else {
            throw UntisError.decodingError("Datumsformatierung fehlgeschlagen.")
        }

        var options: [String: Any] = [
            "startDate": startInt,
            "endDate": endInt
        ]

        if let pId = personId, let pType = personType, pId > 0 {
            options["element"] = [
                "id": pId,
                "type": pType
            ]
        }

        let rawLessons: [UntisLessonElement] = try await sendRPCRequest(
            endpoint: url,
            method: "getTimetable",
            params: ["options": options],
            sessionId: sessionId
        )

        // Viele WebUntis-Installationen liefern in `su`, `te`, `ro` und `kl`
        // nur IDs. Über die Stammdaten werden Fach, Lehrkraft, Raum und Klasse
        // zuverlässig aufgelöst, statt alles als „Unterricht“ anzuzeigen.
        let masterData = await fetchMasterData(credentials: credentials, sessionId: sessionId)
        return mapUntisLessons(rawLessons, periods: periods, masterData: masterData)
    }

    /// Meldet die WebUntis-Session ab
    public func logout(credentials: UntisCredentials, sessionId: String) async {
        guard let url = credentials.rpcEndpointURL else { return }
        let _: IgnoredRPCResult? = try? await sendRPCRequest(
            endpoint: url,
            method: "logout",
            params: [:],
            sessionId: sessionId
        )
    }

    // MARK: - Helper Mapping

    private func mapUntisLessons(
        _ rawList: [UntisLessonElement],
        periods: [Period],
        masterData: MasterData
    ) -> [Lesson] {
        var lessons: [Lesson] = []

        let outFormatter = DateFormatter()
        outFormatter.dateFormat = "yyyy-MM-dd"
        outFormatter.locale = Locale(identifier: "en_US_POSIX")

        let inFormatter = DateFormatter()
        inFormatter.dateFormat = "yyyyMMdd"
        inFormatter.locale = Locale(identifier: "en_US_POSIX")

        for (idx, raw) in rawList.enumerated() {
            let dateStr: String
            if let d = inFormatter.date(from: "\(raw.date)") {
                dateStr = outFormatter.string(from: d)
            } else {
                let s = "\(raw.date)"
                if s.count == 8 {
                    dateStr = "\(s.prefix(4))-\(s.dropFirst(4).prefix(2))-\(s.suffix(2))"
                } else {
                    dateStr = s
                }
            }

            // Stundennummer ermitteln über Startzeit
            let startMinutes = (raw.startTime / 100) * 60 + (raw.startTime % 100)
            var matchingPeriod = 1
            var minDiff = Int.max

            for p in periods {
                let diff = abs(p.startMinutes - startMinutes)
                if diff < minDiff {
                    minDiff = diff
                    matchingPeriod = p.periodNumber
                }
            }

            let rawSubject = raw.su?.first
            let knownSubject = rawSubject?.id.flatMap { masterData.subjects[$0] }
            let subject = firstNonEmpty(
                rawSubject?.name,
                rawSubject?.longname,
                knownSubject?.name,
                knownSubject?.longname
            ) ?? "Unterricht"

            let rawTeacher = raw.te?.first
            let knownTeacher = rawTeacher?.id.flatMap { masterData.teachers[$0] }
            let teacher = firstNonEmpty(
                rawTeacher?.name,
                rawTeacher?.longname,
                knownTeacher?.name,
                knownTeacher?.longname
            ) ?? ""
            let origTeacher = firstNonEmpty(rawTeacher?.orgname, knownTeacher?.orgname)

            let rawRoom = raw.ro?.first
            let knownRoom = rawRoom?.id.flatMap { masterData.rooms[$0] }
            let room = firstNonEmpty(
                rawRoom?.name,
                rawRoom?.longname,
                knownRoom?.name,
                knownRoom?.longname
            ) ?? ""
            let origRoom = firstNonEmpty(rawRoom?.orgname, knownRoom?.orgname)

            let rawClass = raw.kl?.first
            let knownClass = rawClass?.id.flatMap { masterData.classes[$0] }
            let klasse = firstNonEmpty(
                rawClass?.name,
                rawClass?.longname,
                knownClass?.name,
                knownClass?.longname
            ) ?? ""

            let isCancelled = (raw.code?.lowercased() == "cancelled") ||
                (raw.statflags?.contains("x") == true) ||
                (raw.substText?.lowercased().contains("entfällt") == true) ||
                (raw.substText?.lowercased().contains("fällt aus") == true)

            let isSubstitution = (raw.code?.lowercased() == "irregular") ||
                (origTeacher != nil && origTeacher != teacher && !teacher.isEmpty) ||
                (origRoom != nil && origRoom != room && !room.isEmpty) ||
                (raw.substText != nil && !raw.substText!.isEmpty && !isCancelled)

            let lesson = Lesson(
                id: raw.id != nil ? "\(raw.id!)" : "untis_\(dateStr)_\(matchingPeriod)_\(idx)",
                dateString: dateStr,
                periodNumber: matchingPeriod,
                durationPeriods: 1,
                subjectRaw: subject,
                teacherRaw: teacher,
                roomRaw: room,
                klasseRaw: klasse,
                isCancelled: isCancelled,
                isSubstitution: isSubstitution,
                substitutionText: raw.substText ?? "",
                originalTeacher: origTeacher != teacher ? origTeacher : nil,
                originalRoom: origRoom != room ? origRoom : nil,
                originalSubject: nil,
                info: nil
            )

            lessons.append(lesson)
        }

        return lessons
    }

    /// Liefert den ersten vorhandenen und nicht-leeren Text zurück.
    private func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}
