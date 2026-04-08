import Foundation
import SwiftData

enum Weekday: Int, Codable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday
}

@Model
class SubjectSchedule {
    var dayOfWeek: Weekday
    // 時限（→時限のない授業スケジュールなんて存在しない）
    var period: PeriodSetting

    // 「1学期」など
    var timetable: Timetable?

    // 教科(Subject)
    var sourceSubject: Subject

    // この枠から生成されたLessonたち。この枠を消せば、この枠にこれまであった教科のlessonは、sourceScheduleという所属を失う。
    @Relationship(deleteRule: .nullify, inverse: \Lesson.sourceSchedule) var lessons: [Lesson] = []
    
    init(dayOfWeek: Weekday, period: PeriodSetting) {
        self.dayOfWeek = dayOfWeek
        self.period = period
    }
}
