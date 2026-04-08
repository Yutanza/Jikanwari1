import Foundation
import SwiftData

@Model
// 「1学期」など、時間割表の区分を管理するためのモデル
class Timetable {
    var name: String
    var startDate: Date?
    var endDate: Date?

    // 追加: ユーザーが画面上で表示させたい時限数 (デフォルトを6などに設定)
    var visiblePeriodCount: Int = 6

    // この時間割に紐づく時限設定たち →この時間割を削除すると、時限も道連れ削除される
    @Relationship(deleteRule: .cascade, inverse: \PeriodSetting.timeTable) var periodSettings: [PeriodSetting] = []
    
    // この時間割に紐付くLessonたち →この時間割を削除すると、timeTableという所属を失う
    @Relationship(deleteRule: .nullify, inverse: \Lesson.timetable) 
    var lessons: [Lesson] = []
    
    // この時間割に紐付く「コマ（教科）+時限」たち →この時間割削除で道連れ
    @Relationship(deleteRule: .cascade , inverse: \SubjectSchedule.timetable) 
    var schedules: [SubjectSchedule] = []
    
    init(name: String, startDate: Date, endDate: Date) {
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
    }
}
