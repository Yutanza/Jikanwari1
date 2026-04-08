import Foundation
import SwiftData

@Model
class PeriodSetting {
    var periodNumber: Int   
    var startHour: Int?   
    var startMinute: Int?    
    var endHour: Int?        
    var endMinute: Int?         

    var timeTable: Timetable


    // この時限を使っているスケジュールたちを連鎖削除
    @Relationship(deleteRule: .cascade, inverse: \SubjectSchedule.period)
    var schedules: [SubjectSchedule] = []

    // PeriodSettingは、TimeTable削除時に消されるため、ここではnullify設定に。
    @Relationship(deleteRule: .nullify, inverse: \Lesson.period)
    var lessons: [Lesson] = []

    init(periodNumber: Int, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        self.periodNumber = periodNumber
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }
}
